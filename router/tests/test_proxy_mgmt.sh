#!/bin/sh
# Fixture tests: proxy-mgmt.cgi — per-node delay probes via a stubbed controller.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
CGI="$HERE/../x28/dashboard/cgi/proxy-mgmt.sh"

PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (expect [$2] got [$3])"; fi; }
assert_contains() { if printf '%s' "$3" | grep -qF "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (missing: $2)"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

command -v jq >/dev/null 2>&1 || { echo "jq not available; skipping"; summary; exit 0; }

# stub controller: fake curl responding to mihomo API paths
STUB="$TMP/bin"; mkdir -p "$STUB"
cat > "$STUB/curl" <<'EOF'
#!/bin/sh
u=""
for a in "$@"; do case "$a" in http*) u="$a"; break ;; esac; done
case "$u" in
  *"proxies/auto"*)                    echo '{"all":["vps-reality","cdn-ws","hy2"],"now":"cdn-ws"}' ;;
  *"/proxies/vps-reality/delay"*)      echo '{"delay":120}' ;;
  *"/proxies/cdn-ws/delay"*)           echo '{"delay":85}' ;;
  *"/proxies/hy2/delay"*)              echo '{"error":"timeout"}' ;;
  *"/proxies/vps-reality"*)            echo '{"alive":true,"type":"Vless"}' ;;
  *"/proxies/cdn-ws"*)                 echo '{"alive":true,"type":"Vless"}' ;;
  *"/proxies/hy2"*)                    echo '{"alive":false,"type":"Hysteria2"}' ;;
esac
EOF
chmod +x "$STUB/curl"

run_cgi() {
    PATH="$STUB:$PATH" MIHOMO_CTRL="http://stub" JQ_BIN="$(command -v jq)" QUERY_STRING="$1" sh "$CGI" | tail -n +4
}

# ── single-node delay probe ─────────────────────────────────────────────────
out=$(run_cgi "test=cdn-ws")
assert_contains "test returns the node name" '"node":"cdn-ws"' "$out"
assert_contains "test returns latency ms" '"delay":85' "$out"

out=$(run_cgi "test=vps-reality")
assert_contains "test vps-reality delay" '"delay":120' "$out"

# dead node → error path, still a JSON response
out=$(run_cgi "test=hy2")
assert_contains "dead node delay=error" '"delay":"error"' "$out"

# ── list still works with the seam (baseline guard) ─────────────────────────
out=$(run_cgi "list")
assert_contains "list active node" '"active":"cdn-ws"' "$out"
assert_contains "list first node" '"name":"vps-reality"' "$out"
assert_contains "list node alive" '"alive":true' "$out"

# ── ping=all: parallel probes, one round-trip ───────────────────────────────
out=$(run_cgi "ping=all")
assert_contains "ping=all opens nodes array" '"nodes":[' "$out"
assert_contains "ping=all vps-reality delay" '"name":"vps-reality","delay":120' "$out"
assert_contains "ping=all cdn-ws delay" '"name":"cdn-ws","delay":85' "$out"
assert_contains "ping=all dead node error" '"name":"hy2","delay":"error"' "$out"
n=$(printf '%s' "$out" | grep -o '"name"' | wc -l | tr -d ' ')
assert_eq "ping=all covers all members" "3" "$n"

summary