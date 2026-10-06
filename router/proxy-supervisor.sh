#!/bin/sh
# /root/proxy-supervisor.sh — Unified Proxy Health & Failover Supervisor
# Single source of truth for:
# - Canonical SOCKS :1080 dual-endpoint probing (Google + Cloudflare)
# - Hysteresis state machine (anti-flap failover and auto-recovery)
# - Atomic dnsmasq + nftables transitions

PROXY_SUP_STATE_FILE="${PROXY_SUP_STATE_FILE:-/tmp/proxy-watchdog.state}"
PROXY_SUP_SOCKS="${PROXY_SUP_SOCKS:-127.0.0.1:1080}"
PROXY_SUP_URL_GOOGLE="${PROXY_SUP_URL_GOOGLE:-http://connectivitycheck.gstatic.com/generate_204}"
PROXY_SUP_URL_CLOUDFLARE="${PROXY_SUP_URL_CLOUDFLARE:-http://cp.cloudflare.com/generate_204}"
PROXY_SUP_FAIL_THRESH="${PROXY_SUP_FAIL_THRESH:-5}"
PROXY_SUP_PASS_THRESH="${PROXY_SUP_PASS_THRESH:-3}"

# Read state or set defaults
proxy_sup_load_state() {
    MODE="proxy"
    FAILS=0
    PASSES=0
    LAST_CHECK=0
    LAST_LAT=""
    if [ -f "$PROXY_SUP_STATE_FILE" ]; then
        . "$PROXY_SUP_STATE_FILE" 2>/dev/null
    fi
}

proxy_sup_save_state() {
    mkdir -p "$(dirname "$PROXY_SUP_STATE_FILE")" 2>/dev/null
    cat <<EOF > "$PROXY_SUP_STATE_FILE"
MODE="$MODE"
FAILS=$FAILS
PASSES=$PASSES
LAST_CHECK="$(date +%s)"
LAST_LAT="$LAST_LAT"
EOF
}

# Real network actions for Fail-Open and Restore
proxy_sup_apply_failopen() {
    logger -t proxy-supervisor "CRITICAL: Engaging FAIL-OPEN to direct cellular (X28)." 2>/dev/null || true
    # 1. Flush transparent redirect table
    nft delete table inet axproxy 2>/dev/null || true
    # 2. Point dnsmasq directly to modem DNS
    if command -v uci >/dev/null 2>&1; then
        uci -q delete dhcp.@dnsmasq[0].server || true
        uci add_list dhcp.@dnsmasq[0].server="192.168.70.1"
        uci commit dhcp 2>/dev/null || true
        /etc/init.d/dnsmasq restart 2>/dev/null || true
    fi
}

proxy_sup_apply_restore() {
    logger -t proxy-supervisor "RECOVERY: Proxy restored (stable passes). Re-engaging encrypted proxy." 2>/dev/null || true
    # 1. Restore sing-box DNS in dnsmasq
    if command -v uci >/dev/null 2>&1; then
        uci -q delete dhcp.@dnsmasq[0].server || true
        uci add_list dhcp.@dnsmasq[0].server="127.0.0.1#5354"
        uci commit dhcp 2>/dev/null || true
        /etc/init.d/dnsmasq restart 2>/dev/null || true
    fi
    # 2. Reapply nftables rules
    if [ -x /etc/axproxy.sh ]; then
        /etc/axproxy.sh 2>/dev/null || true
    fi
}

# Canonical dual-endpoint probe over SOCKS
proxy_sup_probe() {
    local out code lat
    # 1. Check Google endpoint
    out=$(curl -sS -m 4 -x "socks5h://$PROXY_SUP_SOCKS" -o /dev/null -w "%{http_code}|%{time_total}" "$PROXY_SUP_URL_GOOGLE" 2>/dev/null)
    code=${out%%|*}; lat=${out##*|}
    if [ "$code" = "204" ]; then
        echo "up|${lat:-0}"
        return 0
    fi

    # 2. Check Cloudflare endpoint
    out=$(curl -sS -m 4 -x "socks5h://$PROXY_SUP_SOCKS" -o /dev/null -w "%{http_code}|%{time_total}" "$PROXY_SUP_URL_CLOUDFLARE" 2>/dev/null)
    code=${out%%|*}; lat=${out##*|}
    if [ "$code" = "204" ]; then
        echo "up|${lat:-0}"
        return 0
    fi

    echo "down|"
    return 1
}

# Status query: mode=...|fails=...|passes=...|last_lat=...|last_check=...
proxy_sup_status() {
    proxy_sup_load_state
    echo "mode=$MODE|fails=$FAILS|passes=$PASSES|last_lat=$LAST_LAT|last_check=$LAST_CHECK"
}

# Single hysteresis tick
proxy_sup_tick() {
    proxy_sup_load_state
    local res lat
    res=$(proxy_sup_probe)
    lat=${res##*|}

    if [ "${res%%|*}" = "up" ]; then
        LAST_LAT="$lat"
        if [ "$MODE" = "failopen" ]; then
            PASSES=$((PASSES + 1))
            if [ "$PASSES" -ge "$PROXY_SUP_PASS_THRESH" ]; then
                MODE="proxy"
                FAILS=0
                PASSES=0
                proxy_sup_apply_restore
            fi
        else
            FAILS=0
        fi
    else
        LAST_LAT=""
        if [ "$MODE" = "proxy" ]; then
            FAILS=$((FAILS + 1))
            if [ "$FAILS" -ge "$PROXY_SUP_FAIL_THRESH" ]; then
                MODE="failopen"
                FAILS=0
                PASSES=0
                proxy_sup_apply_failopen
            fi
        else
            PASSES=0
        fi
    fi
    proxy_sup_save_state
}

# Force manual switch to 'proxy' or 'failopen'
proxy_sup_switch() {
    proxy_sup_load_state
    local target="$1"
    if [ "$target" = "failopen" ]; then
        MODE="failopen"
        FAILS=0
        PASSES=0
        proxy_sup_apply_failopen
    elif [ "$target" = "proxy" ]; then
        MODE="proxy"
        FAILS=0
        PASSES=0
        proxy_sup_apply_restore
    else
        echo "Usage: proxy_sup_switch <proxy|failopen>" >&2
        return 1
    fi
    proxy_sup_save_state
}

# CLI dispatcher
case "${1:-}" in
    probe)  proxy_sup_probe ;;
    status) proxy_sup_status ;;
    tick)   proxy_sup_tick ;;
    switch) proxy_sup_switch "$2" ;;
esac
