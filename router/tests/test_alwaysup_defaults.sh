#!/bin/sh
# Unit tests: always-up defaults — failover cadence constants live in the
# deployed scripts; these pin the tightened defaults so a revert is caught.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n' "$2"; printf '  actual: [%s]\n' "$3"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }

WD="$HERE/../x28/operator-watchdog.sh"
HEAL="$HERE/../x28/x28-vps-heal.sh"

# watchdog: 60s interval, threshold still 3, storm guard intact
assert_eq "watchdog interval default 60" "60" "$(grep -oE 'WATCHDOG_INTERVAL:-[0-9]+' "$WD" | cut -d- -f2 | head -1)"
assert_eq "watchdog fails threshold 3" "3" "$(grep -oE 'WATCHDOG_FAILS:-[0-9]+' "$WD" | cut -d- -f2 | head -1)"
assert_eq "watchdog max/hour 3" "3" "$(grep -oE 'WATCHDOG_MAX_H:-[0-9]+' "$WD" | cut -d- -f2 | head -1)"
assert_eq "watchdog cooldown 600" "600" "$(grep -oE 'WATCHDOG_COOLDOWN:-[0-9]+' "$WD" | cut -d- -f2 | head -1)"

# vps-heal: 4-min dead threshold, 60s poll, panel target intact
assert_eq "heal dead-threshold default 4" "4" "$(grep -oE 'HEAL_DEAD_THRESHOLD:-[0-9]+' "$HEAL" | cut -d- -f2 | head -1)"
assert_eq "heal poll 60s" "60" "$(grep -oE 'HEAL_SLEEP:-[0-9]+' "$HEAL" | cut -d- -f2 | head -1)"
grep -q "restartSb" "$HEAL" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - restartSb action missing"; }
# heal notifies on action (card fires when restart triggered / skipped)
grep -q "notify" "$HEAL" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - heal notify missing"; }

summary
