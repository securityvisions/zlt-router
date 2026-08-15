#!/bin/sh
# tproxy-disable.sh — remove the X28 transparent proxy (back to SOCKS-only).
# Canonical copy lives in this repo (router/x28/tproxy-disable.sh); deploys to
# the X28 as /data/proxy/tproxy-disable.sh.

set -eu

XRAY_CONF="${XRAY_CONF:-/data/proxy/sing-box/xray-proxy.json}"
XRAY_TPROXY_CONF="${XRAY_TPROXY_CONF:-/data/proxy/sing-box/xray-tproxy.json}"

# Remove the REDIRECT rules.
iptables -t nat -D PREROUTING -i br0 -j X28_TPROXY 2>/dev/null || true
iptables -t nat -F X28_TPROXY 2>/dev/null || true
iptables -t nat -X X28_TPROXY 2>/dev/null || true

# Point the service back at the SOCKS-only config.
sed -i "s|$XRAY_TPROXY_CONF|$XRAY_CONF|" /etc/init.d/x28proxy
/etc/init.d/x28proxy restart

echo "X28 transparent proxy disabled."
