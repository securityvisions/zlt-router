#!/bin/sh
# stage2-disable.sh — revert the X28 to SOCKS-only crypto engine.
# Canonical copy lives in this repo (router/x28/stage2-disable.sh); deploys to
# the X28 as /data/proxy/stage2-disable.sh.

set -eu

XRAY_CONF="${XRAY_CONF:-/data/proxy/sing-box/xray-proxy.json}"
XRAY_SPLIT_CONF="${XRAY_SPLIT_CONF:-/data/proxy/sing-box/xray-split.json}"

iptables -t nat -D PREROUTING -i br0 -j X28_SPLIT 2>/dev/null || true
iptables -t nat -F X28_SPLIT 2>/dev/null || true
iptables -t nat -X X28_SPLIT 2>/dev/null || true

sed -i "s|$XRAY_SPLIT_CONF|$XRAY_CONF|" /etc/init.d/x28proxy
/etc/init.d/x28proxy restart

echo "X28 Stage-2 split proxy disabled (SOCKS-only restored)."
echo "Re-enable PassWall on the AX3000T: uci set passwall.@global[0].enabled='1' && uci commit passwall && /etc/init.d/passwall restart"
