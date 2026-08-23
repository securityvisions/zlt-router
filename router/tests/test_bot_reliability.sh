#!/bin/sh
# Regression tests: bot reliability fixes (structural + behavioral seams).
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
BOT="$HERE/../x28/x28-bot.sh"

PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n' "$2"; printf '  actual: [%s]\n' "$3"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }

# H2 keeper-orphan fix: keeper must watch its parent pid
grep -q 'kill -0 "$BOTPID"' "$BOT" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - keeper does not watch parent"; }
# M1 callback staleness guard + instant ack before dispatch
grep -q 'cbdate' "$BOT" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - no callback staleness field"; }
ackline=$(grep -n 'answer_cbq "\$cbid"' "$BOT" | head -1 | cut -d: -f1)
caseline=$(grep -n 'case "\$action" in' "$BOT" | head -1 | cut -d: -f1)
[ -n "$ackline" ] && [ -n "$caseline" ] && [ "$ackline" -lt "$caseline" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - ack not before dispatch"; }
# M2 offset persisted AFTER handling (after the last command arm)
offline=$(grep -n 'echo "\$off" > "\$PSTATE/offset"' "$BOT" | tail -1 | cut -d: -f1)
lastarm=$(grep -n 'Unknown command' "$BOT" | head -1 | cut -d: -f1)
[ -n "$offline" ] && [ -n "$lastarm" ] && [ "$offline" -gt "$lastarm" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - offset still written before handling"; }
# M3 strict arg validation helper exists and is used for user args
grep -q 'safe_arg' "$BOT" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - safe_arg missing"; }
# M4 response-aware transport logging
grep -q 'tg_post()' "$BOT" && grep -q '"tg: .*FAILED' "$BOT" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - tg_post logging missing"; }
# H3 edit falls back to send on failure
grep -q 'edit_html()' "$BOT" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - edit_html fallback missing"; }
# H4 jq boot guard alerts instead of zombie-looping
grep -q 'jq missing' "$BOT" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - jq guard missing"; }
# M5 instance lock
grep -q 'mkdir "$STATEDIR/lock"' "$BOT" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - mkdir lock missing"; }
# HTML formatting system active
grep -q 'parse_mode=HTML' "$BOT" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - HTML parse mode missing"; }
grep -q 'expandable' "$BOT" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - expandable sections unused"; }
# supervisor cleans lock between restarts
grep -q 'rm -rf "$STATEDIR/lock"' "$BOT" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - supervisor lock cleanup missing"; }

summary

# refine wifi-incident ban: bare `continue` is forbidden INSIDE the per-update
# batch loop (it would skip i++), but is legitimate in the outer poll error path.
inner=$(sed -n '/while \[ "\$i" -lt "\$n" \]; do/,/^        done$/p' "$BOT")
printf '%s' "$inner" | grep -qE '^[[:space:]]*continue[[:space:]]*$' && { FAIL=$((FAIL+1)); echo "FAIL - bare continue inside update loop"; } || PASS=$((PASS+1))
# random-MAC detection present in redesigned fmt_devices
grep -q '26aeAE' "$BOT" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - random MAC detection missing"; }

summary
