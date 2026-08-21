#!/bin/sh
# Enable X28 transparent proxy with the FIXED split config (geoip-only, no geosite:ir).
# Reversible with tproxy-fixed-disable.sh
set -eu
iptables -t nat -N X28_SPLIT 2>/dev/null || iptables -t nat -F X28_SPLIT
iptables -t nat -A X28_SPLIT -d 192.168.70.0/24 -j RETURN
iptables -t nat -A X28_SPLIT -p tcp -j REDIRECT --to-ports 12345
iptables -t nat -D PREROUTING -i br0 -j X28_SPLIT 2>/dev/null || true
iptables -t nat -A PREROUTING -i br0 -j X28_SPLIT
iptables -t mangle -N X28_NOQUIC 2>/dev/null || iptables -t mangle -F X28_NOQUIC
iptables -t mangle -A X28_NOQUIC -p udp --dport 443 -j DROP
iptables -t mangle -D PREROUTING -i br0 -j X28_NOQUIC 2>/dev/null || true
iptables -t mangle -A PREROUTING -i br0 -j X28_NOQUIC
iptables -t nat -I X28_SPLIT 1 -d 185.137.27.122 -j RETURN 2>/dev/null || true
echo "transparent proxy enabled (QUIC blocked)"
