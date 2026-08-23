#!/bin/sh
# Unit tests: rescue supervisor decision (hn_rescue_decide).
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
HN_LIB="$HERE/../hnlib.sh"
[ -f "$HN_LIB" ] || HN_LIB="$HERE/hnlib.sh"
. "$HN_LIB"
[ -f "$HERE/../ledger-rules.sh" ] && . "$HERE/../ledger-rules.sh"

PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n' "$2"; printf '  actual: [%s]\n' "$3"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }

# promotion path
assert_eq "4-min dead streak + alive rescue -> promote" "promote" "$(hn_rescue_decide 4 0 auto 1 2)"
assert_eq "3-min dead streak -> hold" "hold" "$(hn_rescue_decide 3 0 auto 1 2)"
assert_eq "dead but rescue pool empty -> hold" "hold" "$(hn_rescue_decide 9 0 auto 1 0)"
# demotion path
assert_eq "10-min alive on rescue -> demote" "demote" "$(hn_rescue_decide 0 10 rescue 1 3)"
assert_eq "9-min alive on rescue -> hold" "hold" "$(hn_rescue_decide 0 9 rescue 1 3)"
# disabled forces demotion when riding rescue, holds otherwise
assert_eq "disabled while on rescue -> demote" "demote" "$(hn_rescue_decide 0 0 rescue 0 5)"
assert_eq "disabled while on auto -> hold" "hold" "$(hn_rescue_decide 5 0 auto 0 5)"
# steady states
assert_eq "healthy owned, world auto -> hold" "hold" "$(hn_rescue_decide 0 0 auto 1 2)"
assert_eq "on rescue, not yet stable -> hold" "hold" "$(hn_rescue_decide 2 3 rescue 1 1)"
# garbage inputs treated as zeros
assert_eq "garbage streaks -> hold" "hold" "$(hn_rescue_decide x y auto 1 2)"
# custom thresholds honored
assert_eq "custom promote_after=2" "promote" "$(hn_rescue_decide 2 0 auto 1 1 2)"
assert_eq "custom demote_after=5" "demote" "$(hn_rescue_decide 0 5 rescue 1 1 4 5)"

summary
