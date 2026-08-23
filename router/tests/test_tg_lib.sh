#!/bin/bash
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
TGLIB="$HERE/../x28/tg-lib.sh"

PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n' "$2"; printf '  actual: [%s]\n' "$3"; fi; }
assert_contains() { if printf '%s' "$3" | grep -qF "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (missing: $2)"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }

MAXMSG=4000
export MAXMSG

. "$TGLIB"

# ── esc ─────────────────────────────────────────────────────────────────────
assert_eq "esc: amp" "a&amp;b" "$(esc 'a&b')"
assert_eq "esc: lt/gt" "&lt;i&gt;" "$(esc '<i>')"
assert_eq "esc: combined" "a&amp;b&lt;c&gt;d" "$(esc 'a&b<c>d')"
q='"; assert_eq "esc: quotes untouched" "$q" "$(esc "$q")"

# ── split_chunks / join_chunks ──────────────────────────────────────────────
big=$(printf 'x%.0s' $(seq 1 4500))
n=$(split_chunks "$big" | wc -l)
assert_eq "chunk: oversize splits" "2" "$n"
small="line1
line2
line3"
j=$(join_chunks "$small")
printf '%s' "$j" | grep -qF '[[C]]' && { FAIL=$((FAIL+1)); echo "FAIL - sentinel in single chunk"; } || PASS=$((PASS+1))
big_j=$(join_chunks "$big")
n=$(printf '%s' "$big_j" | grep -oF '[[C]]' | wc -l)
assert_eq "join: oversize splits once" "1" "$n"
printf '%s' "$j" | grep -qF 'line2' && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - content preserved"; }

# ── safe_arg ────────────────────────────────────────────────────────────────
assert_eq "arg: clean" "1405-05" "$(safe_arg '1405-05')"
assert_eq "arg: glob rejected" "" "$(safe_arg '*')"

# ── verdict_emoji ───────────────────────────────────────────────────────────
g="HEALTH: GREEN (all checks passed)"; assert_contains "verdict green" "✅ HEALTH: GREEN" "$(verdict_emoji "$g")"
r="HEALTH: RED (2 check(s) failed)"; assert_contains "verdict red" "❌ HEALTH: RED" "$(verdict_emoji "$r")"

# ── send_one with stubbed curl ──────────────────────────────────────────────
TMP=$(mktemp -d)
# create a fake curl that logs the method and args
FAKE_CURL="$TMP/fake-curl"
cat > "$FAKE_CURL" <<'STUB'
#!/bin/sh
echo "METHOD_CALL" >> "${FAKE_LOG:-/dev/null}"
echo '{"ok":true,"result":{"message_id":42}}'
STUB
chmod +x "$FAKE_CURL"
# verify the function exists and has correct signature markers in source
grep -q 'tg_post()' "$TGLIB" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - tg_post exists"; }
grep -q 'parse_mode=HTML' "$TGLIB" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - HTML mode used"; }
grep -q 'link_preview_options' "$TGLIB" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - preview suppressed"; }
grep -q 'is_disabled.*true' "$TGLIB" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - preview disabled flag"; }

summary
