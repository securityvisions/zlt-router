#!/bin/sh
# steam-tun-disable.sh — remove the Valve/Steam routes through the engine's TUN.
# Removes exactly what steam-tun-enable.sh added, plus the --persist boot hook.
#
# Env seams for tests: IP_BIN, X28_TUN_DEV.
# Canonical copy: router/x28/steam-tun-disable.sh — deploys to /data/proxy/.

STEAM_CIDRS="162.254.192.0/18 155.133.128.0/17 146.66.152.0/21 208.64.200.0/22 185.25.182.0/23"
DEV="${X28_TUN_DEV:-utun}"
IPC="${IP_BIN:-ip}"
# must mirror enable: LAN traffic lives in vendor table 17000, local in main
TABLES="${STEAM_TUN_TABLES:-main 17000}"

for c in $STEAM_CIDRS; do
    for t in $TABLES; do
        $IPC route del "$c" dev "$DEV" table "$t" 2>/dev/null
    done
done

sed -i '\|/data/proxy/steam-tun-enable.sh|d' /etc/rc.local 2>/dev/null

echo "Steam/Valve tun routes removed — Steam traffic is back on the direct path."
exit 0