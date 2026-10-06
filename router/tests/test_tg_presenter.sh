#!/bin/sh
# Unit tests: router/tg-presenter.sh — pure presentation and formatting engine
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n' "$2"; printf '  actual: [%s]\n' "$3"; fi; }
assert_contains() { if printf '%s' "$3" | grep -qF "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (missing: $2)"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }

. "$HERE/../tg-presenter.sh"

# Test 1: HTML Escaping
assert_eq "esc simple" "hello &amp; world" "$(tg_pres_esc 'hello & world')"
assert_eq "esc tags" "&lt;b&gt;bold&lt;/b&gt;" "$(tg_pres_esc '<b>bold</b>')"

# Test 2: Verdict emojis
assert_contains "verdict green" "✅" "$(tg_pres_verdict 'HEALTH: GREEN')"
assert_contains "verdict red" "❌" "$(tg_pres_verdict 'HEALTH: RED')"
assert_contains "verdict warning" "⚠️" "$(tg_pres_verdict 'HEALTH: WARN')"

# Test 3: Card and Blockquote formatting
c=$(tg_pres_card "Status" "CPU: 5%")
assert_contains "card title" "<b>Status</b>" "$c"
assert_contains "card body" "<pre>CPU: 5%</pre>" "$c"

bq=$(tg_pres_blockquote "Log" "line 1")
assert_contains "bq title" "<b>Log</b>" "$bq"
assert_contains "bq body" "<blockquote expandable>line 1</blockquote>" "$bq"

# Test 4: Visual gauges
b=$(tg_pres_bar 50 10)
assert_eq "bar 50%" "▰▰▰▰▰▱▱▱▱▱" "$b"

sp=$(tg_pres_spark "10|20|30|40|50")
assert_eq "sparkline monotonic" "▁▃▅▆█" "$sp"

# Test 5: Temperature badge
assert_eq "temp badge cool" "🟢" "$(tg_pres_temp_badge 45)"
assert_eq "temp badge warm" "🟠" "$(tg_pres_temp_badge 65)"
assert_eq "temp badge hot" "🔴" "$(tg_pres_temp_badge 80)"

summary
