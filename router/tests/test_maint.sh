#!/bin/sh
# Unit tests: maintenance window decision + clock skew guard (hnlib).
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
HN_LIB="$HERE/../hnlib.sh"
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }
[ -f "$HN_LIB" ] || HN_LIB="$HERE/hnlib.sh"
. "$HN_LIB"

PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n' "$2"; printf '  actual: [%s]\n' "$3"; fi; }

# ── hn_maint_should_reboot ──────────────────────────────────────────────────
assert_eq "sunday 05h uptime14 -> reboot" "reboot" "$(hn_maint_should_reboot 7 5 14 500)"
assert_eq "sunday 05h uptime13 ram-ok -> wait" "wait" "$(hn_maint_should_reboot 7 5 13 500)"
assert_eq "saturday 05h uptime30 -> wait" "wait" "$(hn_maint_should_reboot 6 5 30 500)"
assert_eq "monday 05h uptime30 -> wait" "wait" "$(hn_maint_should_reboot 1 5 30 500)"
assert_eq "sunday 06h uptime30 -> wait" "wait" "$(hn_maint_should_reboot 7 6 30 500)"
assert_eq "sunday 04h uptime30 -> wait" "wait" "$(hn_maint_should_reboot 7 4 30 500)"
assert_eq "sunday 05h lowram -> reboot" "reboot" "$(hn_maint_should_reboot 7 5 2 59)"
# boundary: free_mb exactly 60 is NOT low (<60 strict)
assert_eq "sunday 05h ram=60 -> wait" "wait" "$(hn_maint_should_reboot 7 5 2 60)"
assert_eq "boundary: exactly 14d -> reboot" "reboot" "$(hn_maint_should_reboot 7 5 14 100)"
# garbage uptime treated as 0 days; RAM ok -> wait
assert_eq "garbage uptime -> wait (ram ok)" "wait" "$(hn_maint_should_reboot 7 5 garbage 100)"
# garbage uptime + low ram -> reboot (ram axis still works)
assert_eq "garbage uptime, lowram -> reboot" "reboot" "$(hn_maint_should_reboot 7 5 garbage 10)"
# marker blocks a second reboot in the same window
assert_eq "marker same-window -> wait" "wait" "$(hn_maint_should_reboot 7 5 30 500 2026-W34 2026-W34)"
assert_eq "marker different-window -> reboot" "reboot" "$(hn_maint_should_reboot 7 5 30 500 2026-W34 2026-W33)"

# ── hn_clock_skew_ok ────────────────────────────────────────────────────────
assert_eq "skew: within window ok" "ok" "$(hn_clock_skew_ok 1787488000 1787487000)"
assert_eq "skew: default max 1800 exceeded" "skewed" "$(hn_clock_skew_ok 1787492000 1787487000)"
assert_eq "skew: negative delta magnitude counted" "skewed" "$(hn_clock_skew_ok 1787482000 1787487000)"
assert_eq "skew: custom max honored" "ok" "$(hn_clock_skew_ok 1787492000 1787487000 7200)"
assert_eq "skew: unparsable local -> unknown" "unknown" "$(hn_clock_skew_ok abc 1787487000)"
assert_eq "skew: missing remote -> unknown" "unknown" "$(hn_clock_skew_ok 1787488000 '')"

summary

# ── hn_http_date_epoch ──────────────────────────────────────────────────────
assert_eq "httpdate: epoch zero" "0" "$(hn_http_date_epoch 'Thu, 01 Jan 1970 00:00:00 GMT')"
ref=$(date -u -d '2026-08-22 20:48:19' +%s)
assert_eq "httpdate: known instant" "$ref" "$(hn_http_date_epoch 'Sat, 22 Aug 2026 20:48:19 GMT')"
assert_eq "httpdate: garbage -> empty" "" "$(hn_http_date_epoch 'not a date')"
assert_eq "httpdate: empty -> empty" "" "$(hn_http_date_epoch '')"
summary
