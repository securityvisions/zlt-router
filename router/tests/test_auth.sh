#!/bin/sh
# Unit tests: auth (token gate) — every endpoint 401s without the right token.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
. "$HERE/lib.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
echo 'TOKEN=sekrit' > "$TMP/conf"
export RA_CONF="$TMP/conf"

export HTTP_X_ROUTER_TOKEN=sekrit
out=$(run_route GET /status "" "")
assert_eq "correct token => 200" 200 "$(route_status "$out")"

export HTTP_X_ROUTER_TOKEN=wrong
out=$(run_route GET /status "" "")
assert_eq "wrong token => 401" 401 "$(route_status "$out")"
assert_json_eq "wrong token body" '{"error":"unauthorized"}' "$(route_body "$out")"

unset HTTP_X_ROUTER_TOKEN
out=$(run_route GET /status "" "")
assert_eq "missing token => 401" 401 "$(route_status "$out")"

# HTTP Basic auth (the transport uhttpd actually forwards to CGI)
export HTTP_AUTHORIZATION="Basic $(printf 'xirouter:sekrit' | base64)"
out=$(run_route GET /status "" "")
assert_eq "basic auth (xirouter:token) => 200" 200 "$(route_status "$out")"

export HTTP_AUTHORIZATION="Basic $(printf 'sekrit' | base64)"
out=$(run_route GET /status "" "")
assert_eq "basic auth (bare token) => 200" 200 "$(route_status "$out")"

export HTTP_AUTHORIZATION="Basic $(printf 'xirouter:wrong' | base64)"
out=$(run_route GET /status "" "")
assert_eq "basic auth wrong password => 401" 401 "$(route_status "$out")"
unset HTTP_AUTHORIZATION

export HTTP_X_ROUTER_TOKEN=sekrit
out=$(run_route GET /nonsense "" "")
assert_eq "unknown path => 404" 404 "$(route_status "$out")"

summary
