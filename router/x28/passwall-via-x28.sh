#!/bin/sh
# passwall-via-x28.sh — ensure the PassWall "via_x28" node exists.
#
# Canonical copy lives in this repo (router/x28/passwall-via-x28.sh); it runs
# on the AX3000T and is idempotent. The node points at the X28 crypto-engine
# SOCKS inbound (192.168.70.1:1080), so switching PassWall to it offloads the
# tunnel crypto to the X28.

NODE_ID="${NODE_ID:-via_x28}"
SOCKS_ADDR="${SOCKS_ADDR:-192.168.70.1}"
SOCKS_PORT="${SOCKS_PORT:-1080}"
REMARKS="${REMARKS:-via-X28 (4G edge proxy)}"

if ! uci -q get "passwall.$NODE_ID" >/dev/null 2>&1; then
    uci set "passwall.$NODE_ID=nodes"
    uci set "passwall.$NODE_ID.type=sing-box"
    uci set "passwall.$NODE_ID.protocol=socks"
    uci set "passwall.$NODE_ID.address=$SOCKS_ADDR"
    uci set "passwall.$NODE_ID.port=$SOCKS_PORT"
    uci set "passwall.$NODE_ID.remarks=$REMARKS"
    uci set "passwall.$NODE_ID.add_mode=1"
    uci commit passwall
    echo "passwall node $NODE_ID created"
else
    echo "passwall node $NODE_ID already present"
fi
