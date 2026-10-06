#!/bin/sh
# Unit tests: router/routerapi.sh & routerapi_lib.sh — structured response pipeline
set -eu

HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
. "$HERE/lib.sh"

assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if printf '%s' "$haystack" | grep -qF "$needle"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        echo "FAIL - $desc: missing [$needle] in [$haystack]"
    fi
}

# Mock config
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
echo 'TOKEN=secret123' > "$TMP/routerapp.conf"
export RA_CONF="$TMP/routerapp.conf"

. "$HERE/../routerapi_lib.sh"

# Test 1: ra_respond 200 format
out=$(ra_respond 200 '{"ok":true}')
assert_contains "ra_respond 200 header" "Content-Type: application/json" "$out"
assert_contains "ra_respond 200 body" '{"ok":true}' "$out"
# 200 should NOT include Status: line (standard CGI)
if printf '%s' "$out" | grep -q "Status:"; then
    FAIL=$((FAIL + 1))
    echo "FAIL - ra_respond 200 should not emit Status: header"
else
    PASS=$((PASS + 1))
fi

# Test 2: ra_respond error status codes
out401=$(ra_respond 401 '{"error":"unauthorized"}')
assert_contains "ra_respond 401 status" "Status: 401 Unauthorized" "$out401"

out404=$(ra_respond 404 '{"error":"not found"}')
assert_contains "ra_respond 404 status" "Status: 404 Not Found" "$out404"

out400=$(ra_respond 400 '{"error":"bad request"}')
assert_contains "ra_respond 400 status" "Status: 400 Bad Request" "$out400"

# Test 3: ra_handle_request with unauthenticated call
unauth_out=$(REQUEST_METHOD="GET" PATH_INFO="/status" ra_handle_request)
assert_contains "unauth status" "Status: 401 Unauthorized" "$unauth_out"
assert_contains "unauth error" '{"error":"unauthorized"}' "$unauth_out"

# Test 4: ra_handle_request with authenticated 404 call
# Basic auth header for secret123: echo -n "xirouter:secret123" | base64 -> eGlyb3V0ZXI6c2VjcmV0MTIz
auth_hdr="Basic $(printf 'xirouter:secret123' | base64)"
notfound_out=$(HTTP_AUTHORIZATION="$auth_hdr" REQUEST_METHOD="GET" PATH_INFO="/unknown_endpoint_test" ra_handle_request)
assert_contains "notfound status" "Status: 404 Not Found" "$notfound_out"
assert_contains "notfound error" '{"error":"unknown endpoint"}' "$notfound_out"

# Test 5: Verify no temp file leakage in /tmp
before_tmp=$(ls -1 /tmp/routerapi_* 2>/dev/null | wc -l)
HTTP_AUTHORIZATION="$auth_hdr" REQUEST_METHOD="GET" PATH_INFO="/status" sh "$HERE/../routerapi.sh" >/dev/null 2>&1 || true
after_tmp=$(ls -1 /tmp/routerapi_* 2>/dev/null | wc -l)
assert_eq "zero temp files created" "$before_tmp" "$after_tmp"

summary
