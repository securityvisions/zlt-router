#!/bin/sh
# udp-tproxy-enable.sh — all-UDP transparent proxy via TPROXY.
#
# LAN UDP flows enter the proxy engine's tproxy port; the engine's rules
# decide the path (Iranian UDP stays DIRECT via GEOIP, foreign UDP exits via
# the VPS). TCP is untouched (still the REDIRECT path). Returns protect the
# VPS IP, the LAN, multicast and broadcast so DHCP/mDNS/DNS keep working.
# Idempotent; --persist also installs the boot hook in /etc/rc.local.
#
# Env seams for tests: IPTABLES_BIN, IP_BIN, X28_TPROXY_PORT, X28_TPROXY_MARK.
# Canonical copy: router/x28/udp-tproxy-enable.sh — deploys to /data/proxy/.

IPT="${IPTABLES_BIN:-iptables}"
IPC="${IP_BIN:-ip}"
PORT="${X28_TPROXY_PORT:-12346}"
MARK="${X28_TPROXY_MARK:-0x1/0x1}"
VPS="185.137.27.122/32"

$IPT -t mangle -N X28_UDPT 2>/dev/null || $IPT -t mangle -F X28_UDPT
$IPT -t mangle -C PREROUTING -i br0 -j X28_UDPT 2>/dev/null || \
    $IPT -t mangle -A PREROUTING -i br0 -j X28_UDPT

for d in "$VPS" 192.168.70.0/24 224.0.0.0/4 255.255.255.255/32; do
    $IPT -t mangle -C X28_UDPT -d "$d" -j RETURN 2>/dev/null || \
        $IPT -t mangle -A X28_UDPT -d "$d" -j RETURN
done

$IPT -t mangle -C X28_UDPT -p udp -j TPROXY --on-port "$PORT" --tproxy-mark "$MARK" 2>/dev/null || \
    $IPT -t mangle -A X28_UDPT -p udp -j TPROXY --on-port "$PORT" --tproxy-mark "$MARK"

# TPROXY return path: marked packets route back via the local table
$IPC rule show 2>/dev/null | grep -q "fwmark 0x1" || $IPC rule add fwmark 0x1 table 100
$IPC route show table 100 2>/dev/null | grep -q local || $IPC route add local 0.0.0.0/0 dev lo table 100

if [ "${1:-}" = "--persist" ]; then
    if ! grep -q "udp-tproxy-enable" /etc/rc.local 2>/dev/null; then
        sed -i '/^exit 0/i /data/proxy/udp-tproxy-enable.sh' /etc/rc.local 2>/dev/null
    fi
fi

echo "UDP TPROXY enabled (port $PORT, mark $MARK). Disable: /data/proxy/udp-tproxy-disable.sh"
exit 0