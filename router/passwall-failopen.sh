#!/bin/sh
# passwall-failopen.sh — Thin compatibility facade delegating to proxy-watchdog.sh.
#
# Canonical copy lives in this repo (router/passwall-failopen.sh).
# Deployed to AX3000T as /root/passwall-failopen.sh.

DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
WATCHDOG="$DIR/proxy-watchdog.sh"
[ -f "$WATCHDOG" ] || WATCHDOG="/root/proxy-watchdog.sh"

if [ -f "$WATCHDOG" ]; then
    exec /bin/sh "$WATCHDOG" "$@"
else
    echo "ERROR: proxy-watchdog.sh not found" >&2
    exit 1
fi
