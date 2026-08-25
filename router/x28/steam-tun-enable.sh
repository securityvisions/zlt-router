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
WAIT="${STEAM_TUN_WAIT:-30}"   # seconds to wait for the tun at boot (rc.local
                               # can beat the engine's tun creation)

# Wait for the tun device: at boot the persist hook may run before the
# engine creates it. Adding routes against a missing device failed silently
# here once already (2026-08-25 voice outage) — never do that again.
i=0
while ! $IPC link show dev "$DEV" >/dev/null 2>&1; do
    if [ "$i" -ge "$WAIT" ]; then
        echo "ERROR: tun device $DEV did not appear within ${WAIT}s — is the engine running with tun enabled? Routes NOT applied." >&2
        exit 1
    fi
    i=$((i+1))
    sleep 1
done

for c in $STEAM_CIDRS; do
    $IPC route show 2>/dev/null | grep -qF "$c dev $DEV" || $IPC route add "$c" dev "$DEV"
done

# Verify every route actually landed; partial success is failure
for c in $STEAM_CIDRS; do
    if ! $IPC route show 2>/dev/null | grep -qF "$c dev $DEV"; then
        echo "ERROR: route for $c via $DEV missing after add." >&2
        exit 1
    fi
done

if [ "${1:-}" = "--persist" ]; then
    RC_FILE="${RC_FILE:-/etc/rc.local}"   # test seam: redirect for fixtures
    if ! grep -q "steam-tun-enable" "$RC_FILE" 2>/dev/null; then
        sed -i '/^exit 0/i /data/proxy/steam-tun-enable.sh' "$RC_FILE" 2>/dev/null
    fi
fi

echo "Steam/Valve traffic routed via tun $DEV. Disable: /data/proxy/steam-tun-disable.sh"
exit 0