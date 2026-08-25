#!/bin/sh
# steam-tun-enable.sh — route Valve/Steam traffic through the engine's TUN.
#
# mihomo's tun (gvisor stack, /dev/net/tun) carries UDP+TCP transparently
# in userspace, so no iptables TPROXY is needed. This adds routes for the
# known Valve/Steam CIDRs via the tun device: Steam voice (UDP) and Steam
# game/signalling TCP enter the engine, whose rules proxy them through the
# VPS. Everything else on the LAN keeps its normal path. Idempotent;
# --persist also installs the boot hook in /etc/rc.local.
#
# Env seams for tests: IP_BIN, X28_TUN_DEV.
# Canonical copy: router/x28/steam-tun-enable.sh — deploys to /data/proxy/.

STEAM_CIDRS="162.254.192.0/18 155.133.240.0/20 146.66.152.0/21 208.64.200.0/22 185.25.182.0/23"
DEV="${X28_TUN_DEV:-utun}"
IPC="${IP_BIN:-ip}"

$IPC link show dev "$DEV" >/dev/null 2>&1 || \
    echo "WARNING: tun device $DEV not up yet — is the engine running with tun enabled?"

for c in $STEAM_CIDRS; do
    $IPC route show 2>/dev/null | grep -qF "$c dev $DEV" || $IPC route add "$c" dev "$DEV"
done

if [ "${1:-}" = "--persist" ]; then
    if ! grep -q "steam-tun-enable" /etc/rc.local 2>/dev/null; then
        sed -i '/^exit 0/i /data/proxy/steam-tun-enable.sh' /etc/rc.local 2>/dev/null
    fi
fi

echo "Steam/Valve traffic routed via tun $DEV. Disable: /data/proxy/steam-tun-disable.sh"
exit 0