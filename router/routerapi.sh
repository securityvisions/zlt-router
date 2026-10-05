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

ra_handle_request

