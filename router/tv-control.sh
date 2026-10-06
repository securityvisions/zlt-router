#!/bin/sh
# /usr/sbin/tv-control.sh — Samsung Q70C Control helper (Facade to media-gateway.sh)
MG="/usr/sbin/media-gateway.sh"
[ -f "$MG" ] || MG="/root/media-gateway.sh"
[ -f "$MG" ] || MG="$(dirname "$0")/media-gateway.sh"

case "${1:-status}" in
    wake|on) exec "$MG" tv wake ;;
    status)  exec "$MG" tv status ;;
    *) echo "Usage: $0 {wake|status}" ;;
esac
