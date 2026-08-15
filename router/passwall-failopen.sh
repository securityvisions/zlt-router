#!/bin/sh
# passwall-failopen.sh — VPN health watchdog with node rotation.
#
# Canonical copy lives in this repo (router/passwall-failopen.sh); deployed to
# the AX3000T as /root/passwall-failopen.sh (minute cron). Checks whether the
# active PassWall node actually proxies internet; on failure it rotates to the
# next node in the chain and only disables PassWall (fail-open to direct) once
# every node has been tried. Auto-recovery is handled by passwall-autorecover.sh.
#
# Chain order (cheapest/most reliable first): Cloudflare-fronted cdn_ws, direct
# VPS REALITY, VPS Hysteria2, then the X28 edge proxy (via_x28).

set -eu

LOCK_DIR=/tmp/passwall-health.lock
COUNT_FILE=/tmp/passwall-fail-count
MARKER=/root/.passwall-disabled-by-failopen
VPN_CHECK=/tmp/passwall-vpn-health-ip

# Failover chain: rotate through these before failing open to direct.
CHAIN="${PW_CHAIN:-cdn_ws eFCgnGrZ hyst_vps via_x28}"

mkdir "$LOCK_DIR" 2>/dev/null || exit 0
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT INT TERM

# pw_next <current> — prints the next node in CHAIN after current, or "" at end.
pw_next() {
    local cur="$1" next="" found=0 n
    for n in $CHAIN; do
        if [ "$found" = 1 ]; then next="$n"; break; fi
        [ "$n" = "$cur" ] && found=1
    done
    echo "$next"
}

# pw_healthy — true when the active node actually proxies internet.
pw_healthy() {
    pgrep -f '/TCP.*SOCKS.json' >/dev/null 2>&1 &&
        wget -q -T 12 -O "$VPN_CHECK" https://api.ipify.org &&
        grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' "$VPN_CHECK"
}

# pw_rotate — move tcp_node to the next node in the chain and restart PassWall.
# Returns 0 on rotation, 1 when there is no next node (chain exhausted).
pw_rotate() {
    local cur next
    cur=$(uci -q get passwall.@global[0].tcp_node || true)
    next=$(pw_next "$cur")
    [ -n "$next" ] || return 1
    uci set passwall.@global[0].tcp_node="$next"
    uci commit passwall
    /etc/init.d/passwall restart >/dev/null 2>&1 || true
    logger -t passwall-health "rotated node ${cur:-?} -> $next"
    return 0
}

pw_failopen() {
    uci set passwall.@global[0].enabled='0'
    uci set passwall.@global[0].acl_enable='0'
    uci commit passwall
    /etc/init.d/passwall stop
    uci -q delete dhcp.@dnsmasq[0].extraconftext || true
    uci commit dhcp
    /etc/init.d/dnsmasq restart
    date +%s > "$MARKER"
    rm -f "$COUNT_FILE"
    logger -t passwall-health "fail-open: PassWall disabled; waiting for direct internet and a healthy node"
}

main() {
    local count
    if [ "$(uci -q get passwall.@global[0].enabled || true)" != "1" ]; then
        rm -f "$COUNT_FILE"
        exit 0
    fi

    if pw_healthy; then
        rm -f "$COUNT_FILE"
        exit 0
    fi

    count=$(cat "$COUNT_FILE" 2>/dev/null || echo 0)
    count=$((count + 1))
    echo "$count" > "$COUNT_FILE"
    logger -t passwall-health "VPN health check failed ${count}/5"

    # After two consecutive failures, move to the next node (and keep the
    # network on PassWall while we try it). Fail open only once the chain is
    # exhausted and five checks have failed.
    if [ "$count" -ge 2 ] && pw_rotate; then
        rm -f "$COUNT_FILE"
        exit 0
    fi

    if [ "$count" -ge 5 ]; then
        pw_failopen
    fi
}

case "${1:-}" in
    --next) pw_next "$2" ;;
    --health) pw_healthy && echo healthy || echo unhealthy ;;
    *) main ;;
esac
