#!/bin/sh
# Xirouter Router API — uhttpd CGI dispatcher.
#
# Deploy on the router:
#   cp routerapi_lib.sh routerapi.sh /www/cgi-bin/
#   chmod 755 /www/cgi-bin/routerapi.sh /www/cgi-bin/routerapi_lib.sh
#   echo 'TOKEN=<secret>' > /etc/routerapp.conf && chmod 600 /etc/routerapp.conf
# Test:  curl -H 'X-Router-Token: <secret>' http://192.168.1.1/cgi-bin/routerapi.sh/status
#
# uhttpd exposes REQUEST_METHOD, PATH_INFO, QUERY_STRING and header env
# (X-Router-Token -> HTTP_X_ROUTER_TOKEN); a POST body arrives on stdin.
DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
. "$DIR/routerapi_lib.sh"

ra_route > "/tmp/routerapi_body.$$" 2>/dev/null
code=${RA_STATUS:-200}

printf 'Content-Type: application/json\n'
[ "$code" != "200" ] && printf 'Status: %s\n' "$code"
printf '\n'
cat "/tmp/routerapi_body.$$"
rm -f "/tmp/routerapi_body.$$"
