#!/bin/sh
# Unit tests: bot-wonderful Panel framework — inline keyboard + Card seam.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
BOT="$HERE/../x28/x28-bot.sh"
LIB="$HERE/../botlib.sh"

PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Test 1: Panel keyboard JSON structure (4 rows × 2, callback_data panel:*)
# We test the helper function panel_keyboard (to be added to x28-bot.sh) via sourcing
# For now, test that botlib card helper is beautiful (bar/spark present)
. "$LIB" 2>/dev/null
out=$(card "Test" "body")
echo "$out" | grep -q "──────────────" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - card divider"; }
echo "$out" | grep -q "<pre>body</pre>" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - card pre"; }
# bar helper (each ▰/▱ is 3 bytes UTF-8; count characters, not bytes)
b=$(bar 50 10)
blen=$(printf "%s" "$b" | wc -m | tr -d ' ')
[ "$blen" -eq 10 ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - bar width 10 got $blen"; }
echo "$b" | grep -q "▰" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - bar filled"; }
# spark helper
s=$(spark "1|2|3|4|5")
[ -n "$s" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - spark"; }
# temp_badge
tb=$(temp_badge 80)
echo "$tb" | grep -q "🔴" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - temp_badge hot"; }
tb=$(temp_badge 50)
echo "$tb" | grep -q "🟢" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - temp_badge cool"; }

# Test 2: x28-bot.sh has Panel keyboard builder and callback handling
if grep -q "panel_keyboard\|inline_keyboard" "$BOT" 2>/dev/null; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - panel_keyboard not found"; fi
if grep -q "callback_query" "$BOT" 2>/dev/null; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - callback_query handling not found"; fi
if grep -q "editMessageText" "$BOT" 2>/dev/null; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - editMessageText not found"; fi
if grep -q "answerCallbackQuery" "$BOT" 2>/dev/null; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - answerCallbackQuery not found"; fi

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
# Test 3: help is button-based, commands updated, randomized MAC detection
if grep -q "help_text" /home/parsavisions/home-network/router/x28/x28-bot.sh; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - help_text missing"; fi
grep -q "/balance" /home/parsavisions/home-network/router/x28/x28-bot.sh && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - /balance missing from help"; }
grep -q "is_random_mac\|rnd = 1" /home/parsavisions/home-network/router/x28/x28-bot.sh && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - random MAC detection"; }
grep -q "/devices" /home/parsavisions/home-network/router/x28/x28-bot.sh && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - /devices command"; }

# Test 4: balance fallback (bal_card) — transient ISP failure shows last-good cache
grep -q "bal_card" /home/parsavisions/home-network/router/x28/x28-bot.sh && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - bal_card helper missing"; }
grep -q "cached ~.*live query failed" /home/parsavisions/home-network/router/x28/x28-bot.sh && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - cache fallback note missing"; }
# panel edit no longer double-wraps card titles
grep -q 'edit_panel "$cbmid" "$body"' /home/parsavisions/home-network/router/x28/x28-bot.sh && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - edit_panel still wraps body in extra header"; }
# no bare `continue` in the bot: inside the update batch loop it skips i++ and
# re-fires the same tap forever (the WiFi-panel send-loop incident)
if grep -qE '^[[:space:]]*continue[[:space:]]*$' /home/parsavisions/home-network/router/x28/x28-bot.sh; then FAIL=$((FAIL+1)); echo "FAIL - bare continue in bot loop"; else PASS=$((PASS+1)); fi

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
