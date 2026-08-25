#!/bin/sh
# Structural spec: the dashboard init must keep the web server under procd's
# control. mini_httpd daemonizes unless started with -D; an unflagged start
# escapes procd tracking, and stop/remove leave an orphan still holding :8080.
# Found live by the 2026-08-25 rollback drill (ticket 01,
# x28-insights-fairness). This test exists to make that regression impossible
# to reintroduce silently.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
INIT="$HERE/../x28/x28-dashboard.init"

PASS=0; FAIL=0
assert_contains() { if [ -f "$INIT" ] && grep -qF -- "$2" "$INIT"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (missing: $2)"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }

[ -f "$INIT" ] || { echo "FAIL - dashboard init missing"; echo "PASS=0 FAIL=1"; exit 1; }

assert_contains "web server runs in foreground (-D)"   "-D -C /tmp/mini_dash.conf"
assert_contains "served by mini_httpd"                 "/usr/bin/mini_httpd"
assert_contains "LAN-only bind"                        "host=192.168.70.1"
assert_contains "port 8080"                            "port=8080"
assert_contains "CGI wired into doc root"              "cgipat=cgi-bin/*"

# ── detection power: the same assertions MUST fail on a de-flagged copy ──────
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
sed 's/^    procd_set_param command \/usr\/bin\/mini_httpd -D/    procd_set_param command \/usr\/bin\/mini_httpd/' "$INIT" > "$TMP/init.old"
if [ "$(diff "$INIT" "$TMP/init.old" | grep -c '^[<>]')" -eq 0 ]; then
    FAIL=$((FAIL+1)); echo "FAIL - detection fixture did not actually remove -D"
elif ! grep -qF -- "-D -C /tmp/mini_dash.conf" "$TMP/init.old"; then
    PASS=$((PASS+1))   # old form correctly trips the foreground assertion
else
    FAIL=$((FAIL+1)); echo "FAIL - de-flagged copy still matches foreground assertion"
fi

summary
