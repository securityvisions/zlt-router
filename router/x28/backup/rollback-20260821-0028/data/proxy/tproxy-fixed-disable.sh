#!/bin/sh
# Disable X28 transparent proxy (back to SOCKS-only, keep xray-split config running).
set -eu
iptables -t nat -D PREROUTING -i br0 -j X28_SPLIT 2>/dev/null || true
iptables -t nat -F X28_SPLIT 2>/dev/null || true
iptables -t nat -X X28_SPLIT 2>/dev/null || true
iptables -t mangle -D PREROUTING -i br0 -j X28_NOQUIC 2>/dev/null || true
iptables -t mangle -F X28_NOQUIC 2>/dev/null || true
iptables -t mangle -X X28_NOQUIC 2>/dev/null || true
echo "transparent proxy disabled (SOCKS still on :1080)"
