#!/bin/sh
# Unit tests: write actions — rename, watch, friday, test, proxy switch, reboot.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
. "$HERE/lib.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
: > "$TMP/names"
: > "$TMP/watchlist"
printf 'RATE_FULL_TOMAN=7700\nRATE_FRIDAY_TOMAN=4620\n' > "$TMP/billing.conf"
printf 'TOKEN=t\n' > "$TMP/conf"
export RA_USER_NAMES="$TMP/names"
export RA_WATCHLIST="$TMP/watchlist"
export RA_BILLING_CONF="$TMP/billing.conf"
export RA_CONF="$TMP/conf"
export HTTP_X_ROUTER_TOKEN=t

# --- rename (valid) ---
out=$(run_route POST /device/rename "" '{"mac":"aa:bb:cc:dd:ee:ff","name":"My Phone"}')
assert_eq "rename 200" 200 "$(route_status "$out")"
assert_json_eq "rename ok" '{"ok":true,"mac":"aa:bb:cc:dd:ee:ff","name":"My Phone"}' "$(route_body "$out")"
assert_eq "rename written to user-names" "aa:bb:cc:dd:ee:ff My Phone" "$(cat "$TMP/names")"

# --- rename (invalid name charset) ---
out=$(run_route POST /device/rename "" '{"mac":"aa:bb:cc:dd:ee:ff","name":"<script>"}')
assert_eq "rename bad name 400" 400 "$(route_status "$out")"

# --- rename (missing mac) ---
out=$(run_route POST /device/rename "" '{"name":"X"}')
assert_eq "rename missing mac 400" 400 "$(route_status "$out")"

# --- watch on/off ---
out=$(run_route POST /device/watch "" '{"mac":"00:11:22:33:44:55","on":true}')
assert_json_eq "watch on" '{"ok":true,"watched":true}' "$(route_body "$out")"
assert_eq "watchlist contains mac" "1" "$(grep -c '00:11:22:33:44:55' "$TMP/watchlist")"
out=$(run_route POST /device/watch "" '{"mac":"00:11:22:33:44:55","on":false}')
assert_json_eq "watch off" '{"ok":true,"watched":false}' "$(route_body "$out")"
assert_eq "watchlist empty after off" "0" "$(grep -c '00:11:22:33:44:55' "$TMP/watchlist" || true)"

# --- friday ---
out=$(run_route POST /friday "" '{"friday":true}')
assert_json_eq "friday set" '{"ok":true,"friday":true}' "$(route_body "$out")"
assert_eq "LAST_FRIDAY written" "yes" "$(sed -n 's/^LAST_FRIDAY=//p' "$TMP/billing.conf")"

# --- url test (function override needs the test's own shell, not a route subshell) ---
ra_url_test() { echo "HTTP 200 in 0.31s (IP 1.2.3.4)"; }
RA_BODY='{"url":"https://google.com"}'
out=$(ra_test_url)
assert_json_eq "url test" '{"ok":true,"url":"https://google.com","result":"HTTP 200 in 0.31s (IP 1.2.3.4)"}' "$out"
RA_BODY='{}'
RA_STATUS=200
ra_test_url >/dev/null
assert_eq "url test empty 400" 400 "$RA_STATUS"

# --- proxy switch (guarded: unknown node rejected) ---
RA_BODY='{"node":"bogus"}'
RA_STATUS=200
ra_switch_proxy >/dev/null
assert_eq "proxy unknown node 400" 400 "$RA_STATUS"
RA_BODY='{"node":"hysteria2"}'
RA_STATUS=200
out=$(ra_switch_proxy)
assert_json_eq "proxy switch ok" '{"ok":true,"node":"hysteria2"}' "$out"

# --- reboot (ra_do_reboot is a no-op on non-OpenWrt boxes) ---
out=$(ra_reboot)
assert_json_eq "reboot ok" '{"ok":true}' "$out"

summary
