#!/bin/sh
# Unit tests: bearer-bounce escalation decision (hn_bounce_decide).
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
HN_LIB="$HERE/../hnlib.sh"
[ -f "$HN_LIB" ] || HN_LIB="$HERE/hnlib.sh"
. "$HN_LIB"

PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n' "$2"; printf '  actual: [%s]\n' "$3"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }

# fewer failed rounds than the ladder allows → no
assert_eq "rounds 1 -> no" "no" "$(hn_bounce_decide 1 999999)"
assert_eq "rounds 0 -> no" "no" "$(hn_bounce_decide 0 999999)"
# enough rounds but inside cooldown → no
assert_eq "rounds 2, age 3599 -> no" "no" "$(hn_bounce_decide 2 3599)"
# boundary: rounds=2 and cooldown fully elapsed → yes
assert_eq "rounds 2, age 3600 -> yes" "yes" "$(hn_bounce_decide 2 3600)"
# many rounds, never bounced (age default huge) → yes
assert_eq "rounds 5, fresh -> yes" "yes" "$(hn_bounce_decide 5 '')"
# garbage inputs treated as safe defaults
assert_eq "garbage rounds -> no" "no" "$(hn_bounce_decide garbage 100)"
assert_eq "garbage age -> treated huge" "yes" "$(hn_bounce_decide 3 garbage)"
# overrides honored
assert_eq "after=1 override" "yes" "$(hn_bounce_decide 1 999999 1)"
assert_eq "cooldown=60 override" "yes" "$(hn_bounce_decide 2 60 2 60)"
assert_eq "cooldown override not yet" "no" "$(hn_bounce_decide 2 59 2 60)"

summary
