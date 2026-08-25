#!/bin/sh
# tproxy-enable.sh — X28 transparent proxy for the backup/guest network.
#
# Canonical copy lives in this repo (router/x28/tproxy-enable.sh); it deploys
# to the X28 as /data/proxy/tproxy-enable.sh and is OPT-IN — do not run it on
# the live link unless you intend direct-X28 clients to be proxied. The AX3000T
# (the main router's WAN, 192.168.70.167) is excluded so its own PassWall path
# is untouched.
#
# Adds a dokodemo-door transparent inbound to xray and REDIRECTs LAN TCP from
# every LAN client except the AX3000T through it. Disable with tproxy-disable.sh.

set -eu

EXCLUDE="${X28_EXCLUDE:-192.168.70.167}"          # the AX3000T's WAN IP
LAN="${X28_LAN_SUBNET:-192.168.70.0/24}"
TPROXY_PORT="${X28_TPROXY_PORT:-12345}"
XRAY_CONF="${XRAY_CONF:-/data/proxy/sing-box/xray-proxy.json}"
XRAY_TPROXY_CONF="${XRAY_TPROXY_CONF:-/data/proxy/sing-box/xray-tproxy.json}"

# Build the full xray config: SOCKS (:1080) + transparent (dokodemo-door).
cat > "$XRAY_TPROXY_CONF" <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "tag": "socks-in",
      "listen": "192.168.70.1",
      "port": 1080,
      "protocol": "socks",
      "settings": { "auth": "noauth", "udp": true }
    },
    {
      "tag": "tproxy-in",
      "listen": "192.168.70.1",
      "port": $TPROXY_PORT,
      "protocol": "dokodemo-door",
      "settings": { "network": "tcp,udp" },
      "sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
    }
  ],
  "outbounds": [
    {
      "tag": "vps-reality",
      "protocol": "vless",
      "settings": { "vnext": [ { "address": "85.121.124.158", "port": 443,
        "users": [ { "id": "$(sed -n 's/.*"id": "\([^"]*\)".*/\1/p' "$XRAY_CONF" | head -1)", "encryption": "none" } ] } ] },
      "streamSettings": { "network": "tcp", "security": "reality",
        "realitySettings": { "serverName": "www.bing.com", "fingerprint": "chrome",
          "publicKey": "$(sed -n 's/.*"publicKey": "\([^"]*\)".*/\1/p' "$XRAY_CONF" | head -1)",
          "shortId": "$(sed -n 's/.*"shortId": "\([^"]*\)".*/\1/p' "$XRAY_CONF" | head -1)" } } }
    },
    { "protocol": "freedom", "tag": "direct" }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      { "type": "field", "inboundTag": ["socks-in", "tproxy-in"], "outboundTag": "vps-reality" }
    ]
  }
}
EOF

# Point the x28proxy service at the tproxy config and restart.
sed -i "s|$XRAY_CONF|$XRAY_TPROXY_CONF|" /etc/init.d/x28proxy
/etc/init.d/x28proxy restart
sleep 2

# REDIRECT LAN TCP (excluding the AX3000T) into the transparent inbound.
iptables -t nat -N X28_TPROXY 2>/dev/null || iptables -t nat -F X28_TPROXY
iptables -t nat -A X28_TPROXY -d 192.168.70.0/24 -j RETURN
iptables -t nat -A X28_TPROXY -s "$EXCLUDE" -j RETURN
iptables -t nat -A X28_TPROXY -p tcp -j REDIRECT --to-ports "$TPROXY_PORT"
iptables -t nat -D PREROUTING -i br0 -j X28_TPROXY 2>/dev/null || true
iptables -t nat -A PREROUTING -i br0 -j X28_TPROXY

echo "X28 transparent proxy enabled (excluding $EXCLUDE). Disable: /data/proxy/tproxy-disable.sh"
