#!/bin/sh
# Unit tests: router/proxy-watchdog.sh — 5-state resilience machine
set -eu

HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
W="$HERE/../proxy-watchdog.sh"

PASS=0
FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        echo "FAIL - $desc: expected [$expected] got [$actual]"
    fi
}

TMPDIR=$(mktemp -d /tmp/pw-test.XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT

export PW_STATE_DIR="$TMPDIR/state"
export PW_MARKER="$TMPDIR/disabled-marker"
mkdir -p "$PW_STATE_DIR"

# 1. Test state determination
assert_eq "initial state healthy" "HEALTHY" "$(PW_STATE_DIR="$PW_STATE_DIR" PW_MARKER="$PW_MARKER" sh "$W" --state)"

# 2. Test degraded state
echo "1" > "$PW_STATE_DIR/quality-count"
assert_eq "quality count > 0 is degraded" "DEGRADED" "$(PW_STATE_DIR="$PW_STATE_DIR" PW_MARKER="$PW_MARKER" sh "$W" --state)"

# 3. Test failopen state
touch "$PW_MARKER"
assert_eq "marker present is failopen" "FAILOPEN" "$(PW_STATE_DIR="$PW_STATE_DIR" PW_MARKER="$PW_MARKER" sh "$W" --state)"
rm -f "$PW_MARKER"

# 4. Test status output key=val
echo "0" > "$PW_STATE_DIR/quality-count"
echo "2" > "$PW_STATE_DIR/fail-count"
st=$(PW_STATE_DIR="$PW_STATE_DIR" PW_MARKER="$PW_MARKER" sh "$W" status)
assert_eq "status reports state" "HEALTHY" "$(echo "$st" | sed -n 's/^state=//p')"
assert_eq "status reports fail_count" "2" "$(echo "$st" | sed -n 's/^fail_count=//p')"

# 5. Test status output JSON
st_json=$(PW_STATE_DIR="$PW_STATE_DIR" PW_MARKER="$PW_MARKER" sh "$W" status --json)
assert_eq "json reports state" "HEALTHY" "$(echo "$st_json" | jq -r '.state')"
assert_eq "json reports fail_count" "2" "$(echo "$st_json" | jq -r '.fail_count')"

# 6. Test chain next traversal
assert_eq "chain cdn_ws -> eFCgnGrZ" "eFCgnGrZ" "$(sh "$W" --next cdn_ws)"
assert_eq "chain via_x28 -> empty" "" "$(sh "$W" --next via_x28)"

echo "=== test_proxy_watchdog: PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ]
