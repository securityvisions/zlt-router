#!/bin/sh
# Fixture tests: the health gate's dashboard slice.
# Contract: x28-health.sh gains dashboard availability checks (static page +
# one API snapshot) whose PASS/FAIL lines feed the existing GREEN/RED verdict
# and exit code; X28_HEALTH_GROUPS filters sections (default: all, prod
# unchanged); DASH_BASE_URL redirects the probe for testing.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
HEALTH="$HERE/../x28/x28-health.sh"

PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n' "$2"; printf '  actual: [%s]\n' "$3"; fi; }
assert_contains() { if printf '%s' "$3" | grep -qF "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (missing: $2)"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

start_server() {  # start_server <docroot> <tag> — prints http://127.0.0.1:<port>
    local root="$1" tag="$2" try port i code pid
    for try in 1 2 3 4 5; do
        port=$((20000 + $$ % 20000 + try))   # POSIX-safe per-run base; retry on collision
        python3 -m http.server "$port" --bind 127.0.0.1 --directory "$root" >"$TMP/srv$tag.log" 2>&1 &
        pid=$!
        for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
            code=$(curl -s -m 1 -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/" 2>/dev/null)
            [ "$code" = "200" ] && { echo $pid > "$TMP/srv$tag.pid"; printf 'http://127.0.0.1:%s' "$port"; return 0; }
            sleep 0.2
        done
        kill "$pid" 2>/dev/null
    done
    return 1
}
stop_server() { [ -f "$TMP/srv$1.pid" ] && kill "$(cat "$TMP/srv$1.pid")" 2>/dev/null; return 0; }

# fixture docroot: page + API snapshot endpoint
mkdir -p "$TMP/www/api"
echo '{}' > "$TMP/www/index.html"
echo '{"health_verdict":"green"}' > "$TMP/www/api/status.json"

# ── 1. both up → PASS/PASS + GREEN + exit 0 ──────────────────────────────────
URL=$(start_server "$TMP/www" 1)
out=$(X28_HEALTH_GROUPS=dash DASH_BASE_URL="$URL" sh "$HEALTH"); rc=$?
assert_eq "up: exit code"        "0"        "$rc"
assert_contains "up: page check" "PASS dash_page" "$out"
assert_contains "up: api check"  "PASS dash_api"  "$out"
assert_contains "up: verdict"    "HEALTH: GREEN"  "$out"
stop_server 1

# ── 2. page up but API missing → mixed verdict RED + nonzero exit ────────────
mkdir -p "$TMP/www2"
echo '{}' > "$TMP/www2/index.html"
URL=$(start_server "$TMP/www2" 2)
out=$(X28_HEALTH_GROUPS=dash DASH_BASE_URL="$URL" sh "$HEALTH"); rc=$?
assert_contains "api-missing: page still passes" "PASS dash_page"   "$out"
assert_contains "api-missing: api fails"         "FAIL dash_api"    "$out"
assert_contains "api-missing: verdict RED"       "HEALTH: RED"      "$out"
[ "$rc" -ne 0 ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - api-missing should exit nonzero"; }
stop_server 2

# ── 3. nothing listening → FAIL/FAIL + RED + nonzero exit ────────────────────
out=$(X28_HEALTH_GROUPS=dash DASH_BASE_URL="http://127.0.0.1:1" sh "$HEALTH"); rc=$?
assert_contains "dead: page fails"  "FAIL dash_page" "$out"
assert_contains "dead: api fails"   "FAIL dash_api"  "$out"
assert_contains "dead: verdict RED" "HEALTH: RED"    "$out"
[ "$rc" -ne 0 ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - dead should exit nonzero"; }

# ── 4. default run (no filter) wires the dashboard section ───────────────────
# Structural check only: cases 1-3 prove behavior; this proves an unfiltered
# production run includes the dash group without probing the real device.
grep -q 'run_group dash' "$HEALTH" && grep -q 'probe dash_page' "$HEALTH" \
  && grep -q 'probe dash_api' "$HEALTH" && PASS=$((PASS+1)) \
  || { FAIL=$((FAIL+1)); echo "FAIL - dashboard section not wired into default health run"; }

summary
