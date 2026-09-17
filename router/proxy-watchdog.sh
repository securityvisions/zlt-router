#!/bin/sh
# /usr/sbin/proxy-watchdog.sh — Autonomous Anti-Flap Fail-Open Watchdog
# Probes local SOCKS proxy :1080 every 30 seconds using Dual-Endpoints (Google + Cloudflare).
# Only counts a failure if BOTH endpoints fail.
# If dead for 5 consecutive cycles (150s = 2.5 min): drops nftables redirect and switches dnsmasq to 192.168.70.1 (Direct).
# If alive for 3 consecutive cycles (90s) from fail-open: restores nftables redirect and encrypted sing-box DNS.
# Zero reboots, zero packet loss, high hysteresis to prevent flapping.

STATE_FILE="/tmp/proxy-watchdog.state"
INTERVAL=30
URL_GOOGLE="http://connectivitycheck.gstatic.com/generate_204"
URL_CLOUDFLARE="http://cp.cloudflare.com/generate_204"

MODE="proxy"
FAILS=0
PASSES=0

if [ -f "$STATE_FILE" ]; then
    . "$STATE_FILE" 2>/dev/null
fi

probe_proxy() {
    if [ -x /usr/sbin/probe-service.sh ]; then
        /usr/sbin/probe-service.sh check passwall >/dev/null 2>&1 && return 0 || return 1
    fi
    # Inline fallback
    code=$(curl -s -m 5 -x socks5h://127.0.0.1:1080 -o /dev/null -w "%{http_code}" "$URL_GOOGLE" 2>/dev/null)
    [ "$code" = "204" ] && return 0
    code=$(curl -s -m 5 -x socks5h://127.0.0.1:1080 -o /dev/null -w "%{http_code}" "$URL_CLOUDFLARE" 2>/dev/null)
    [ "$code" = "204" ] && return 0
    return 1
}

probe_direct() {
    if [ -x /usr/sbin/probe-service.sh ]; then
        /usr/sbin/probe-service.sh direct >/dev/null 2>&1 && return 0 || return 1
    fi
    # Inline fallback
    code=$(curl -s -m 4 -o /dev/null -w "%{http_code}" "$URL_GOOGLE" 2>/dev/null)
    [ "$code" = "204" ] && return 0
    code=$(curl -s -m 4 -o /dev/null -w "%{http_code}" "$URL_CLOUDFLARE" 2>/dev/null)
    [ "$code" = "204" ] && return 0
    ping -c 2 -W 2 192.168.70.1 >/dev/null 2>&1
}

save_state() {
    cat << S_EOF > "$STATE_FILE"
MODE="$MODE"
FAILS=$FAILS
PASSES=$PASSES
LAST_CHECK="$(date +%s)"
S_EOF
}

engage_failopen() {
    logger -t proxy-watchdog "CRITICAL: All proxy nodes dead across both endpoints for 150s. Engaging FAIL-OPEN to direct cellular."
    
    # 1. Flush nftables redirect so client TCP goes direct
    nft delete table inet axproxy 2>/dev/null || true
    
    # 2. Point dnsmasq directly to X28 modem to prevent DNS blackouts
    uci -q delete dhcp.@dnsmasq[0].server; uci add_list dhcp.@dnsmasq[0].server="192.168.70.1"
    uci commit dhcp
    /etc/init.d/dnsmasq restart
    
    MODE="failopen"
    FAILS=0
    PASSES=0
    save_state
}

restore_proxy() {
    logger -t proxy-watchdog "RECOVERY: Proxy nodes confirmed stable (3 consecutive passes). Restoring encrypted proxy and DNS."
    
    # 1. Restore sing-box DNS in dnsmasq
    uci -q delete dhcp.@dnsmasq[0].server; uci add_list dhcp.@dnsmasq[0].server="127.0.0.1#5354"
    uci commit dhcp
    /etc/init.d/dnsmasq restart
    
    # 2. Re-apply transparent proxy rules
    /etc/axproxy.sh
    
    MODE="proxy"
    FAILS=0
    PASSES=0
    save_state
}

logger -t proxy-watchdog "Watchdog daemon started (Cycle: ${INTERVAL}s, Anti-Flap: 5 fail / 3 pass, Dual-Endpoints)"

while true; do
    if probe_proxy; then
        if [ "$MODE" = "failopen" ]; then
            PASSES=$((PASSES + 1))
            logger -t proxy-watchdog "Proxy probe PASSED ($PASSES/3 required for recovery)"
            if [ "$PASSES" -ge 3 ]; then
                restore_proxy
            else
                save_state
            fi
        else
            FAILS=0
            save_state
        fi
    else
        if [ "$MODE" = "proxy" ]; then
            FAILS=$((FAILS + 1))
            logger -t proxy-watchdog "Proxy probe FAILED on dual endpoints ($FAILS/5 before fail-open)"
            if [ "$FAILS" -ge 5 ]; then
                if probe_direct; then
                    engage_failopen
                else
                    logger -t proxy-watchdog "Proxy probe failed but direct link also down; holding state."
                fi
            else
                save_state
            fi
        else
            PASSES=0
            save_state
        fi
    fi
    sleep "$INTERVAL"
done
