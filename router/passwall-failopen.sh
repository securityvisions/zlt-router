#!/bin/sh
set -eu

LOCK_DIR=/tmp/passwall-health.lock
COUNT_FILE=/tmp/passwall-fail-count
MARKER=/root/.passwall-disabled-by-failopen
VPN_CHECK=/tmp/passwall-vpn-health-ip

mkdir "$LOCK_DIR" 2>/dev/null || exit 0
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT INT TERM

ENABLED="$(uci -q get passwall.@global[0].enabled || true)"
if [ "$ENABLED" != "1" ]; then
  rm -f "$COUNT_FILE"
  exit 0
fi

if pgrep -f '/TCP.*SOCKS.json' >/dev/null 2>&1 &&
   wget -q -T 12 -O "$VPN_CHECK" https://api.ipify.org &&
   grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' "$VPN_CHECK"; then
  rm -f "$COUNT_FILE"
  exit 0
fi

COUNT="$(cat "$COUNT_FILE" 2>/dev/null || echo 0)"
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNT_FILE"
logger -t passwall-health "VPN health check failed ${COUNT}/5"

if [ "$COUNT" -ge 5 ]; then
  uci set passwall.@global[0].enabled='0'
  uci set passwall.@global[0].acl_enable='0'
  uci commit passwall
  /etc/init.d/passwall stop
  uci -q delete dhcp.@dnsmasq[0].extraconftext || true
  uci commit dhcp
  /etc/init.d/dnsmasq restart
  date +%s > "$MARKER"
  rm -f "$COUNT_FILE"
  logger -t passwall-health "fail-open: PassWall disabled; waiting for direct internet and a healthy node"
fi
