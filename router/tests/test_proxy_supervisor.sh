#!/bin/sh
# Unit tests: router/proxy-supervisor.sh — unified proxy health & failover supervisor.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
. "$HERE/lib.sh"

assert_contains() {
    if echo "$3" | grep -q "$2"; then
        PASS=$((PASS+1))
    else
        FAIL=$((FAIL+1))
        echo "FAIL - $1"
        printf '  substring: [%s]\n' "$2"
        printf '  actual:    [%s]\n' "$3"
    fi
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export PROXY_SUP_STATE_FILE="$TMP/proxy-sup.state"
export PROXY_SUP_SOCKS="127.0.0.1:1080"
export PROXY_SUP_FAIL_THRESH=3
export PROXY_SUP_PASS_THRESH=2

. "$HERE/../proxy-supervisor.sh"

# Mock probe functions
MOCK_PROBE_RESULT=0
MOCK_PROBE_LAT="0.12"
proxy_sup_probe() {
    [ "$MOCK_PROBE_RESULT" -eq 0 ] && { echo "up|$MOCK_PROBE_LAT"; return 0; }
    echo "down|"
    return 1
}

# Mock transition side effects
FAILOPEN_CALLED=0
RESTORE_CALLED=0
proxy_sup_apply_failopen() { FAILOPEN_CALLED=$((FAILOPEN_CALLED + 1)); }
proxy_sup_apply_restore() { RESTORE_CALLED=$((RESTORE_CALLED + 1)); }

# Test 1: Initial state
stat=$(proxy_sup_status)
assert_contains "initial status mode is proxy" "mode=proxy" "$stat"

# Test 2: Consecutive failures trigger failopen on 3rd fail
MOCK_PROBE_RESULT=1
proxy_sup_tick
stat=$(proxy_sup_status)
assert_contains "tick 1 fail counted" "fails=1" "$stat"
assert_eq "not yet failed open" "0" "$FAILOPEN_CALLED"

proxy_sup_tick
stat=$(proxy_sup_status)
assert_contains "tick 2 fail counted" "fails=2" "$stat"
assert_eq "not yet failed open" "0" "$FAILOPEN_CALLED"

proxy_sup_tick
stat=$(proxy_sup_status)
assert_contains "tick 3 triggers failopen" "mode=failopen" "$stat"
assert_eq "failopen action executed" "1" "$FAILOPEN_CALLED"

# Test 3: Recovery requires 2 consecutive passes
MOCK_PROBE_RESULT=0
proxy_sup_tick
stat=$(proxy_sup_status)
assert_contains "recovery pass 1 counted" "passes=1" "$stat"
assert_contains "still in failopen mode" "mode=failopen" "$stat"
assert_eq "restore not yet called" "0" "$RESTORE_CALLED"

proxy_sup_tick
stat=$(proxy_sup_status)
assert_contains "recovery pass 2 triggers restore" "mode=proxy" "$stat"
assert_eq "restore action executed" "1" "$RESTORE_CALLED"

# Test 4: Explicit switch
proxy_sup_switch failopen
assert_eq "switch failopen called action" "2" "$FAILOPEN_CALLED"
assert_contains "mode switched to failopen" "mode=failopen" "$(proxy_sup_status)"

proxy_sup_switch proxy
assert_eq "switch proxy called action" "2" "$RESTORE_CALLED"
assert_contains "mode switched to proxy" "mode=proxy" "$(proxy_sup_status)"

summary
