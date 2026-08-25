#!/bin/sh
# Fixture tests: udp-diag — UDP-path diagnostic for the Steam voice question.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
UD="$HERE/../x28/udp-diag.sh"

PASS=0; FAIL=0
assert_contains() { if printf '%s' "$3" | grep -qF "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (missing: $2)"; fi; }
assert_not_contains() { if ! printf '%s' "$3" | grep -qF "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (should NOT contain: $2)"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

command -v jq >/dev/null 2>&1 || { echo "jq not available; skipping"; summary; exit 0; }

# stub controller (mimics the proxy-ping fixture)
STUB="$TMP/bin"; mkdir -p "$STUB"
cat > "$STUB/curl" <<'EOF'
#!/bin/sh
u=""
for a in "$@"; do case "$a" in http*) u="$a"; break ;; esac; done
case "$u" in
  *"proxies/auto"*)               echo '{"all":["vps-reality","cdn-ws","hy2","babaii"],"now":"cdn-ws"}' ;;
  *"/proxies/vps-reality/delay"*) echo '{"delay":769}' ;;
  *"/proxies/cdn-ws/delay"*)      echo '{"delay":1131}' ;;
  *"/proxies/hy2/delay"*)         echo '{"delay":640}' ;;
  *"/proxies/babaii/delay"*)      echo '{"error":"timeout"}' ;;
esac
EOF
chmod +x "$STUB/curl"

# ── nodes: ranked by latency, errors last ───────────────────────────────────
out=$(PATH="$STUB:$PATH" MIHOMO_CTRL="http://stub" JQ_BIN="$(command -v jq)" sh "$UD" nodes)
first=$(printf '%s' "$out" | head -1)
assert_contains "lowest-latency node first" "hy2 640" "$first"
assert_contains "ranked contains vps-reality" "vps-reality 769" "$out"
assert_contains "ranked contains cdn-ws" "cdn-ws 1131" "$out"
assert_contains "dead node shown as error" "babaii error" "$out"

# ── verdict: tun route path named when egress OK + high VPS latency ─────────
out=$(DIAG_EGRESS=pass DIAG_STEAM_REACH=yes DIAG_BEST_MS=640 sh "$UD" verdict)
assert_contains "verdict names the tun route fix" "steam-tun-enable.sh" "$out"
assert_contains "verdict names best node latency" "640 ms" "$out"
assert_contains "verdict flags voice latency risk" "voice will lag" "$out"

# ── verdict: egress broken → bigger issue, not proxy-path time ──────────────
out=$(DIAG_EGRESS=fail DIAG_STEAM_REACH=no DIAG_BEST_MS=0 sh "$UD" verdict)
assert_contains "egress-fail verdict flags upstream" "UDP egress" "$out"
assert_not_contains "egress-fail verdict does not recommend tproxy" "build the TPROXY" "$out"

# ── steam: prints the PC-side UDP test command ──────────────────────────────
out=$(DIAG_STEAM_IP=162.254.197.1 DIAG_STEAM_REACH=yes sh "$UD" steam)
assert_contains "steam check prints pc test" "Test-NetConnection" "$out"

summary