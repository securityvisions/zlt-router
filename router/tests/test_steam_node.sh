#!/bin/sh
# Fixture tests: steam-node — pin Steam voice to a chosen node.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
SN="$HERE/../x28/steam-node.sh"

PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (expect [$2] got [$3])"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/config.yaml" <<'EOF'
proxies:
  - name: vps-reality
    type: vless
  - name: hy2
    type: hysteria2
proxy-groups:
  - name: auto
    type: url-test
    proxies:
      - vps-reality
      - hy2
rules:
  - GEOIP,IR,DIRECT
  - RULE-SET,steam-voice,hy2
  - MATCH,world
EOF
export STEAM_CONFIG="$TMP/config.yaml"
export STEAM_NO_RELOAD=1   # tests: never touch a live controller

# ── current node readout ─────────────────────────────────────────────────────
out=$(sh "$SN" show)
assert_eq "current node" "hy2" "$out"

# ── swap to a valid node ─────────────────────────────────────────────────────
out=$(sh "$SN" vps-reality)
assert_eq "swap ok" "vps-reality" "$(sh "$SN" show)"

# ── swap keeps the rule line well-formed ─────────────────────────────────────
grep -q "RULE-SET,steam-voice,vps-reality" "$TMP/config.yaml" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - rule line not rewritten"; }

# ── invalid node rejected, config untouched ──────────────────────────────────
sh "$SN" nonexistent >/dev/null 2>&1; rc=$?
[ "$rc" != "0" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - invalid node accepted"; }
assert_eq "config unchanged on invalid" "vps-reality" "$(sh "$SN" show)"

summary