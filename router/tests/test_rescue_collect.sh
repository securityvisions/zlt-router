#!/bin/sh
# Unit tests: rescue-collect — extraction, merge/dedupe/cap, gating.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
COLL="$HERE/../x28/rescue-collect.sh"

PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n' "$2"; printf '  actual: [%s]\n' "$3"; fi; }
assert_contains() { if printf "%s" "$3" | grep -qE "^$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (missing: $2)"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# ── extraction from a t.me-style HTML page ──────────────────────────────────
cat > "$TMP/page.html" <<'EOF'
<html><body>
<a href="https://t.me/proxy?server=1.2.3.4">ignored mtproto</a>
<code>vless://11111111-2222-3333-4444-555555555555@example.com:443?security=reality&amp;sni=a.com&amp;pbk=X&amp;sid=b#R1</code>
<code>vmess://eyJhZGQiOiIxLjIuMy40In0=</code>
trojan://pass@tj.example.org:443?sni=tj#TJ
ss://YWVzLTI1Ni1nY206cHc=@5.5.5.5:8388#SS
hy2://auth@6.6.6.6:36712/?obfs=salamander#HY
tuic://aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee:pw@7.7.7.7:443#TU
juicity://aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee:jw@8.8.8.8:8443#JU
</body></html>
EOF
out=$("$COLL" extract "$TMP/page.html")
n=$(echo "$out" | wc -l)
assert_eq "extract: 7 URIs found" "7" "$n"
assert_contains "extract: vless" "^vless://" "$out"
assert_contains "extract: vmess" "^vmess://" "$out"
assert_contains "extract: trojan" "^trojan://" "$out"
assert_contains "extract: ss" "^ss://" "$out"
assert_contains "extract: hy2" "^hy2://" "$out"
assert_contains "extract: tuic" "^tuic://" "$out"
assert_contains "extract: juicity" "^juicity://" "$out"
# mtproto link must NOT appear as a proxy URI
printf '%s' "$out" | grep -q 'server=1.2.3.4' && { FAIL=$((FAIL+1)); echo "FAIL - mtproto leaked"; } || PASS=$((PASS+1))

# ── merge / dedupe / cap via collect with FETCH_CMD stub ────────────────────
DD="$TMP/state"; mkdir -p "$DD/raw"
cat > "$TMP/chans" <<'EOF'
chan_a
chan_b
EOF
cat > "$TMP/fetchstub" <<EOF
#!/bin/sh
case "\$1" in
  chan_a) printf 'vless://11111111-2222-3333-4444-555555555555@a.com:443?type=tcp\nvless://11111111-2222-3333-4444-555555555555@b.com:443?type=tcp\n' ;;
  chan_b) printf 'vless://11111111-2222-3333-4444-555555555555@a.com:443?type=tcp\n' ;;   # dup across channels
esac
EOF
chmod +x "$TMP/fetchstub"

# tunnel gate: no /tmp/dnsmasq.conf on host → would skip; fake the check by
# pointing at an existing file via env override seam (grep target overridable)
cat > "$TMP/dns.conf" <<'EOF'
server=127.0.0.1#5353
no-resolv
EOF

out=$(RESCUE_DIR="$DD" CHANNELS_FILE="$TMP/chans" FETCH_CMD="$TMP/fetchstub" \
      DNS_CONF="$TMP/dns.conf" NOW=1000000000 sh "$COLL" collect)
[ -f "$DD/raw/collected.txt" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - cache not created"; }
c=$(wc -l < "$DD/raw/collected.txt")
assert_eq "dedupe across channels" "2" "$c"
lr=$(cat "$DD/last-fetch")
assert_eq "last-fetch stamped" "1000000000" "$lr"

# second immediate run is age-gated (no change even if stub yields new node)
cat >> "$TMP/fetchstub" <<'EOF'
true
EOF
sed -i '1a case "$1" in chan_a) printf "vless://99999999-8888-7777-6666-555555555555@c.com:443?type=tcp\n";; esac' "$TMP/fetchstub" 2>/dev/null || true
RESCUE_DIR="$DD" CHANNELS_FILE="$TMP/chans" FETCH_CMD="$TMP/fetchstub" \
    DNS_CONF="$TMP/dns.conf" NOW=1000000600 sh "$COLL" collect
c2=$(wc -l < "$DD/raw/collected.txt")
assert_eq "age-gate holds within window" "2" "$c2"

# cap enforcement: RAW_CAP=3 with 4 distinct URIs across two runs past the gate
cat > "$TMP/fetchstub" <<'EOF'
#!/bin/sh
case "$1" in
  chan_a) printf 'vless://11111111-2222-3333-4444-555555555555@d.com:443?type=tcp\nvless://11111111-2222-3333-4444-555555555555@e.com:443?type=tcp\n' ;;
  chan_b) printf 'vless://11111111-2222-3333-4444-555555555555@f.com:443?type=tcp\n' ;;
esac
EOF
echo 0 > "$DD/last-fetch"
RESCUE_DIR="$DD" CHANNELS_FILE="$TMP/chans" FETCH_CMD="$TMP/fetchstub" \
    DNS_CONF="$TMP/dns.conf" RAW_CAP=3 NOW=2000000000 sh "$COLL" collect
c3=$(wc -l < "$DD/raw/collected.txt")
assert_eq "cap enforced (3)" "3" "$c3"

summary
