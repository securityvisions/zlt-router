#!/bin/sh
# udp-tproxy-disable.sh — remove the all-UDP TPROXY path (back to TCP-only).
# Removes exactly what udp-tproxy-enable.sh added, plus the --persist boot hook.
#
# Env seams for tests: IPTABLES_BIN, IP_BIN.
# Canonical copy: router/x28/udp-tproxy-disable.sh — deploys to /data/proxy/.

IPT="${IPTABLES_BIN:-iptables}"
IPC="${IP_BIN:-ip}"

$IPT -t mangle -D PREROUTING -i br0 -j X28_UDPT 2>/dev/null
$IPT -t mangle -F X28_UDPT 2>/dev/null
$IPT -t mangle -X X28_UDPT 2>/dev/null

$IPC rule del fwmark 0x1 table 100 2>/dev/null
$IPC route del local 0.0.0.0/0 dev lo table 100 2>/dev/null

sed -i '\|/data/proxy/udp-tproxy-enable.sh|d' /etc/rc.local 2>/dev/null

echo "UDP TPROXY disabled — transparent path is TCP-only again."
exit 0