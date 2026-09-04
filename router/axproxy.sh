#!/bin/sh
# axproxy.sh — Policy routing and nftables ruleset loader for AX3000T transparent proxy
ip rule del fwmark 0x1 table 100 2>/dev/null || true
ip rule add fwmark 0x1 table 100
ip route flush table 100 2>/dev/null || true
ip route add local 0.0.0.0/0 dev lo table 100
nft delete table inet axproxy 2>/dev/null || true
nft -f /etc/axproxy.nft
