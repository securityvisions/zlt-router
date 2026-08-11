#!/bin/sh
# Xirouter Router API — uhttpd CGI dispatcher.
#
# Deploy on the router:
#   cp routerapi_lib.sh routerapi.sh /www/cgi-bin/
#   chmod 755 /www/cgi-bin/routerapi.sh /www/cgi-bin/routerapi_lib.sh
#   echo 'TOKEN=<secret>' > /etc/routerapp.conf && chmod 600 /etc/routerapp.conf
# Test:  curl -u xirouter:<secret> http://192.168.1.1/cgi-bin/routerapi.sh/status
#
# uhttpd exposes REQUEST_METHOD, PATH_INFO, QUERY_STRING and header env
# (Authorization -> HTTP_AUTHORIZATION); a POST body arrives on stdin.
# NOTE: uhttpd does NOT forward custom X-* headers to CGI, so auth rides the
# standard Authorization header (HTTP Basic; token is the password).
DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
. "$DIR/routerapi_lib.sh"

# ra_route runs in a subshell under the redirection, so RA_STATUS would be lost
# there; it instead emits a trailing "@@STATUS:NNN" line the dispatcher strips.
ra_route 2>/dev/null > "/tmp/routerapi_body.$$"
code=$(sed -n 's/.*@@STATUS:\([0-9]*\).*/\1/p' "/tmp/routerapi_body.$$")
[ -z "$code" ] && code=200
sed '/@@STATUS:/d' "/tmp/routerapi_body.$$" > "/tmp/routerapi_json.$$"

printf 'Content-Type: application/json\n'
if [ "$code" != "200" ]; then
    # uhttpd ignores a bare "Status: NNN" — it needs the reason phrase too.
    case "$code" in
        400) reason="400 Bad Request" ;;
        401) reason="401 Unauthorized" ;;
        404) reason="404 Not Found" ;;
        500) reason="500 Internal Server Error" ;;
        *)   reason="$code" ;;
    esac
    printf 'Status: %s\n' "$reason"
fi
printf '\n'
cat "/tmp/routerapi_json.$$"
rm -f "/tmp/routerapi_body.$$" "/tmp/routerapi_json.$$"
