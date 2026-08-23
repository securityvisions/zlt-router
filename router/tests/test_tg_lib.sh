#!/bin/sh
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
TGLIB="$HERE/../x28/tg-lib.sh"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n' "$2"; printf '  actual: [%s]\n' "$3"; fi; }
assert_contains() { if printf '%s' "$3" | grep -qF "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 missing: $2"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }

MAXMSG=4000
export MAXMSG
. "$TGLIB"

# esc
assert_eq "esc amp" 'a&amp;b' "$(esc 'a&b')"
assert_eq "esc ltgt" '&lt;i&gt;' "$(esc '<i>')"

# split_chunks
big=$(printf 'x%.0s' $(seq 1 4200))
n=$(split_chunks "$big" | grep -c .)
assert_eq "oversize splits" "2" "$n"

# join_chunks
small="line1
line2"
j=$(join_chunks "$small")
printf '%s' "$j" | grep -qF '[[C]]' && FAIL=$((FAIL+1)) || PASS=$((PASS+1))
big_j=$(join_chunks "$big")
n=$(printf '%s' "$big_j" | grep -oF '[[C]]' | wc -l)
assert_eq "oversize joins once" "1" "$n"

# safe_arg
assert_eq "arg clean" "1405-05" "$(safe_arg '1405-05')"

# verdict_emoji
g='HEALTH: GREEN'
v=$(verdict_emoji "$g")
printf '%s' "$v" | grep -qF '✅' && PASS=$((PASS+1)) || FAIL=$((FAIL+1))

# source-level checks (no parens in patterns)
grep -qF 'parse_mode=HTML' "$TGLIB" && PASS=$((PASS+1)) || FAIL=$((FAIL+1))
grep -qF 'link_preview_options' "$TGLIB" && PASS=$((PASS+1)) || FAIL=$((FAIL+1))

summary
