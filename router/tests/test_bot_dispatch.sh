#!/bin/sh
# Unit tests: router/x28/bot-dispatch.sh — isolated command and callback routing
set -eu

HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
DISPATCH="$HERE/../x28/bot-dispatch.sh"

PASS=0
FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        echo "FAIL - $desc: expected [$expected] got [$actual]"
    fi
}

assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if printf '%s' "$haystack" | grep -qF "$needle"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        echo "FAIL - $desc: missing [$needle] in [$haystack]"
    fi
}

. "$DISPATCH"

# 1. Unknown command routing
bot_dispatch_cmd "/foobar_bogus_cmd"
assert_eq "unknown command action" "send_html" "$DISPATCH_ACTION"
assert_contains "unknown command text" "Unknown command" "$DISPATCH_TEXT"

# 2. Carrier switch routing
bot_dispatch_cmd "/switch_mci"
assert_eq "switch mci action" "switch_carrier" "$DISPATCH_ACTION"
assert_eq "switch mci network code" "43211" "$DISPATCH_TEXT"
assert_eq "switch mci label" "MCI" "$DISPATCH_EXTRA"

bot_dispatch_cmd "/switch_rightel"
assert_eq "switch rightel action" "switch_carrier" "$DISPATCH_ACTION"
assert_eq "switch rightel network code" "43220" "$DISPATCH_TEXT"
assert_eq "switch rightel label" "Rightel" "$DISPATCH_EXTRA"

# 3. Privacy command routing
bot_dispatch_cmd "/privacy on"
assert_eq "privacy on action" "send_html" "$DISPATCH_ACTION"
assert_contains "privacy on text" "privacy mode" "$DISPATCH_TEXT"

# 4. TV command routing
bot_dispatch_cmd "/tv on"
assert_eq "tv on action" "send_html" "$DISPATCH_ACTION"

bot_dispatch_cmd "/tv"
assert_eq "tv default action" "send_html" "$DISPATCH_ACTION"

# 5. Callback dispatch routing
bot_dispatch_cb "panel:help" "123"
assert_eq "cb help action" "edit_panel" "$DISPATCH_ACTION"
assert_eq "cb help target mid" "123" "$DISPATCH_EXTRA"

bot_dispatch_cb "panel:unknown_test_action" "456"
assert_eq "cb unknown action" "edit_panel" "$DISPATCH_ACTION"
assert_eq "cb unknown text" "unknown tap" "$DISPATCH_TEXT"

# 6. Ledger callback routing with missing file
bot_dispatch_cb "panel:ledg:/nonexistent/file.txt" "789"
assert_eq "cb ledg missing action" "edit_panel" "$DISPATCH_ACTION"
assert_eq "cb ledg missing text" "page not found" "$DISPATCH_TEXT"

echo "=== test_bot_dispatch: PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ]
