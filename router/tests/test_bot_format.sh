#!/bin/sh
# Unit tests: bot formatting/transport core (sourced in lib mode).
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
BOT="$HERE/../x28/x28-bot.sh"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n' "$2"; printf '  actual: [%s]\n' "$3"; fi; }
assert_contains() { if printf '%s' "$3" | grep -qF "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (missing: $2)"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }

# source the bot in library mode (no config required, no loop)
BOT_MODE=lib . "$BOT"

# ── esc ─────────────────────────────────────────────────────────────────────
assert_eq "esc: amp" "a&amp;b" "$(esc 'a&b')"
assert_eq "esc: lt/gt" "&lt;i&gt;" "$(esc '<i>')"
assert_eq "esc: combined" "a&amp;b&lt;c&gt;d" "$(esc 'a&b<c>d')"
q='"'; assert_eq "esc: quotes untouched" "$q" "$(esc "$q")"
assert_eq "esc: hostile hostname" "phone&lt;b&gt;&amp;x" "$(esc 'phone<b>&x')"

# ── chunker ────────────────────────────────────────────────────────────────
big=$(printf 'x%.0s' $(seq 1 4500))
n=$(split_chunks "$big" | wc -l)
assert_eq "chunk: oversize splits" "2" "$n"
first=$(split_chunks "$big" | head -1 | wc -c)
[ "$first" -le 4096 ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - chunk part exceeds 4096 ($first)"; }
# newline-preferred splitting keeps lines intact
multi=$(for i in $(seq 1 300); do echo "line-$i-padding-padding-padding"; done)
p1=$(split_chunks "$multi" | head -1)
printf '%s\n' "$p1" | grep -qE '^line-[0-9]+-padding-padding-padding$' && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - newline boundary broke a line"; }
small=$(printf 'y%.0s' $(seq 1 100))
n=$(split_chunks "$small" | wc -l)
assert_eq "chunk: small intact" "1" "$n"

# ── safe_arg ────────────────────────────────────────────────────────────────
assert_eq "arg: clean passes" "1405-05" "$(safe_arg '1405-05')"
assert_eq "arg: glob rejected" "" "$(safe_arg '*')"
assert_eq "arg: semicolon rejected" "" "$(safe_arg 'a;b')"
assert_eq "arg: space rejected" "" "$(safe_arg 'a b')"
assert_eq "arg: mac-style allowed" "aa:bb:cc:dd:ee:ff" "$(safe_arg 'aa:bb:cc:dd:ee:ff')"

# ── verdict mapping ─────────────────────────────────────────────────────────
assert_contains "verdict: green" "✅ HEALTH: GREEN" "$(verdict_emoji 'HEALTH: GREEN (all checks passed)')"
assert_eq "verdict: green passthrough" "✅ HEALTH: GREEN (all checks passed)" "$(verdict_emoji 'HEALTH: GREEN (all checks passed)')"
assert_contains "verdict: red" "❌ HEALTH: RED" "$(verdict_emoji 'HEALTH: RED (2 check(s) failed)')"
assert_eq "verdict: unknown" "⚠️ unknown" "$(verdict_emoji '')"

summary
