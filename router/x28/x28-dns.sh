#!/bin/sh
# x28-dns.sh — Unified, idempotent DNS manager for ZLT X28.
#
# Bounded Domain: Local dnsmasq upstream configuration, ISP fallback, and
# DHCP option hygiene. Decoupled from L3/L4 transparent proxy routing.
#
# Interfaces:
#   x28-dns.sh auto     probe tunnel health, apply tunnel or isp mode
#   x28-dns.sh tunnel   force clean anti-censorship upstream (127.0.0.1#5353)
#   x28-dns.sh isp      force ISP resolver fallback
#   x28-dns.sh status   query active upstream and DHCP DNS options

ADBLOCK="${ADBLOCK_CONF:-/data/proxy/adblock/adblock.conf}"
CONF="${DNSMASQ_CONF:-/tmp/dnsmasq.conf}"
LOCK=/tmp/x28-dns.lock

dns_lock_acquire() {
    local i=0
    while ! mkdir "$LOCK" 2>/dev/null; do
        i=$((i + 1))
        [ "$i" -gt 30 ] && return 1
        sleep 1
    done
    return 0
}

dns_lock_release() {
    rmdir "$LOCK" 2>/dev/null || true
}

dns_tunnel_ok() {
    if [ -x /data/proxy/probe-service.sh ]; then
        sh /data/proxy/probe-service.sh check passwall >/dev/null 2>&1 && return 0 || return 1
    fi
    local code
    code=$(curl -s -m 8 -x socks5h://192.168.70.1:1080 -o /dev/null \
        -w '%{http_code}' https://www.instagram.com/ 2>/dev/null || echo 000)
    [ "$code" = "200" ]
}

dns_apply() {
    local mode="${1:-tunnel}"
    local isp_dns tmp_conf

    [ -f "$CONF" ] || { echo "dns: $CONF not found" >&2; return 1; }

    tmp_conf=$(mktemp 2>/dev/null || echo "/tmp/dnsmasq.$$.tmp")

    # 1. Clean previous upstream configurations and strip rogue secondary DHCP option
    sed '\|^server=127\.0\.0\.1#5353$|d; \|^no-resolv$|d; \|^clear-on-reload$|d; \|^server=$|d; \|^server=10\.[0-9.]*$|d; \|^server=217\.[0-9.]*$|d; \|^conf-file=/data/proxy/adblock/adblock\.conf$|d; s|,114\.114\.114\.114||g' "$CONF" > "$tmp_conf" 2>/dev/null || cat "$CONF" > "$tmp_conf"

    # Strip empty trailing lines
    sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' "$tmp_conf" 2>/dev/null || true

    # 2. Append requested mode
    if [ "$mode" = "tunnel" ]; then
        printf '\nno-resolv\nserver=127.0.0.1#5353\n' >> "$tmp_conf"
        if [ -s "$ADBLOCK" ] && ! grep -q "^conf-file=$ADBLOCK$" "$tmp_conf"; then
            printf 'conf-file=%s\n' "$ADBLOCK" >> "$tmp_conf"
        fi
    else
        isp_dns=$(awk '/^nameserver/{print $2; exit}' "${RESOLV_CONF:-/tmp/resolv.conf}" 2>/dev/null || echo 10.201.112.252)
        [ -n "$isp_dns" ] || isp_dns="10.201.112.252"
        printf '\nno-resolv\nserver=%s\n' "$isp_dns" >> "$tmp_conf"
    fi

    # 3. Compare with existing config: skip restart if already identical
    if cmp -s "$CONF" "$tmp_conf" 2>/dev/null; then
        rm -f "$tmp_conf"
        echo "dns: $mode mode already active (no restart needed)"
        return 0
    fi

    mv "$tmp_conf" "$CONF"
    pkill -9 dnsmasq 2>/dev/null || true
    sleep 1
    dnsmasq -C "$CONF" -x /tmp/dnsmasq.pid >/dev/null 2>&1 &
    echo "dns: applied $mode mode (dnsmasq restarted)"
}

dns_auto() {
    if dns_tunnel_ok; then
        dns_apply tunnel
    else
        sleep 2
        if dns_tunnel_ok; then
            dns_apply tunnel
        else
            dns_apply isp
        fi
    fi
}

dns_status() {
    [ -f "$CONF" ] || { echo "error: $CONF not found"; return 1; }
    echo "=== X28 DNS Status ==="
    grep -E '^(server=|no-resolv|conf-file=|dhcp-option=)' "$CONF" 2>/dev/null || echo "(no active settings)"
}

case "${1:-auto}" in
    auto)
        dns_lock_acquire || exit 0
        trap dns_lock_release EXIT
        dns_auto
        ;;
    tunnel)
        dns_lock_acquire || exit 0
        trap dns_lock_release EXIT
        dns_apply tunnel
        ;;
    isp)
        dns_lock_acquire || exit 0
        trap dns_lock_release EXIT
        dns_apply isp
        ;;
    status)
        dns_status
        ;;
    *)
        echo "Usage: $0 {auto|tunnel|isp|status}" >&2
        exit 1
        ;;
esac
