#!/bin/sh
# Enable X28 transparent proxy with the FIXED split config (geoip-only, no geosite:ir).
# Reversible with tproxy-fixed-disable.sh
set -eu
# 1. DNS Interception (hardcoded 8.8.8.8 / 1.1.1.1 protection for ZL-5G clients)
iptables -t nat -N X28_DNS 2>/dev/null || iptables -t nat -F X28_DNS
iptables -t nat -A X28_DNS -s 192.168.70.2 -j RETURN
iptables -t nat -A X28_DNS -p udp --dport 53 -j REDIRECT --to-ports 53
iptables -t nat -A X28_DNS -p tcp --dport 53 -j REDIRECT --to-ports 53
iptables -t nat -D PREROUTING -i br0 -j X28_DNS 2>/dev/null || true
iptables -t nat -I PREROUTING 1 -i br0 -j X28_DNS

# 2. Transparent TCP Interception
iptables -t nat -N X28_SPLIT 2>/dev/null || iptables -t nat -F X28_SPLIT
iptables -t nat -A X28_SPLIT -s 192.168.70.2 -j RETURN
iptables -t nat -A X28_SPLIT -d 185.137.27.122 -j RETURN
iptables -t nat -A X28_SPLIT -d 192.168.70.0/24 -j RETURN
iptables -t nat -A X28_SPLIT -p tcp -j REDIRECT --to-ports 12345
iptables -t nat -D PREROUTING -i br0 -j X28_SPLIT 2>/dev/null || true
iptables -t nat -A PREROUTING -i br0 -j X28_SPLIT

# 3. QUIC Drop (forces fast fallback to proxied HTTP/2 over TCP)
iptables -t mangle -N X28_NOQUIC 2>/dev/null || iptables -t mangle -F X28_NOQUIC
iptables -t mangle -A X28_NOQUIC -p udp --dport 443 -j DROP
iptables -t mangle -D PREROUTING -i br0 -j X28_NOQUIC 2>/dev/null || true
iptables -t mangle -A PREROUTING -i br0 -j X28_NOQUIC

echo "transparent proxy enabled (DNS captured, QUIC blocked, AX3000T 192.168.70.2 bypassed)"
