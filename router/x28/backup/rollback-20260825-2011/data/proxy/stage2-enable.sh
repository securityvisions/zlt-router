#!/bin/sh
# stage2-enable.sh — make the X28 the PRIMARY proxy edge (split routing).
#
# Canonical copy lives in this repo (router/x28/stage2-enable.sh); it deploys
# to the X28 as /data/proxy/stage2-enable.sh. OPT-IN Stage 2 — run only after
# the Stage-1 crypto engine has proven stable. Enables the full
# domestic/international split on the X28 (geoip/geosite:ir direct, everything
# else via the VPS) and transparent-proxies the whole LAN. The AX3000T's
# PassWall must then be set to direct (see stage2 note). Revert:
# stage2-disable.sh.

set -eu

LAN="${X28_LAN_SUBNET:-192.168.70.0/24}"
TPROXY_PORT="${X28_TPROXY_PORT:-12345}"
XRAY_CONF="${XRAY_CONF:-/data/proxy/sing-box/xray-proxy.json}"
XRAY_SPLIT_CONF="${XRAY_SPLIT_CONF:-/data/proxy/sing-box/xray-split.json}"
ASSETS="${XRAY_ASSETS:-/data/proxy}"

getf() { sed -n "s/.*\"$1\": \"\([^\"]*\)\".*/\1/p" "$XRAY_CONF" | head -1; }

cat > "$XRAY_SPLIT_CONF" <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    { "tag": "socks-in", "listen": "192.168.70.1", "port": 1080,
      "protocol": "socks", "settings": { "auth": "noauth", "udp": true } },
    { "tag": "tproxy-in", "listen": "192.168.70.1", "port": $TPROXY_PORT,
      "protocol": "dokodemo-door", "settings": { "network": "tcp,udp" },
      "sniffing": { "enabled": true, "destOverride": ["http", "tls"] } }
  ],
  "outbounds": [
    { "tag": "vps-reality", "protocol": "vless",
      "settings": { "vnext": [ { "address": "85.121.124.158", "port": 443,
        "users": [ { "id": "$(getf id)", "encryption": "none" } ] } ] },
      "streamSettings": { "network": "tcp", "security": "reality",
        "realitySettings": { "serverName": "www.bing.com", "fingerprint": "chrome",
          "publicKey": "$(getf publicKey)", "shortId": "$(getf shortId)" } } },
    { "protocol": "freedom", "tag": "direct" }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      { "type": "field", "outboundTag": "direct", "ip": ["geoip:ir", "geoip:private"] },
      { "type": "field", "outboundTag": "direct", "domain": ["geosite:ir"] },
      { "type": "field", "inboundTag": ["socks-in", "tproxy-in"], "outboundTag": "vps-reality" }
    ]
  }
}
EOF

sed -i "s|$XRAY_CONF|$XRAY_SPLIT_CONF|" /etc/init.d/x28proxy
/etc/init.d/x28proxy restart
sleep 2

# Transparent-proxy the WHOLE LAN (Stage 2: the X28 is the primary edge).
iptables -t nat -N X28_SPLIT 2>/dev/null || iptables -t nat -F X28_SPLIT
iptables -t nat -A X28_SPLIT -d 192.168.70.0/24 -j RETURN
iptables -t nat -A X28_SPLIT -p tcp -j REDIRECT --to-ports "$TPROXY_PORT"
iptables -t nat -D PREROUTING -i br0 -j X28_SPLIT 2>/dev/null || true
iptables -t nat -A PREROUTING -i br0 -j X28_SPLIT

echo "X28 Stage-2 split proxy enabled."
echo "Now on the AX3000T: uci set passwall.@global[0].enabled='0' && uci commit passwall && /etc/init.d/passwall stop"
