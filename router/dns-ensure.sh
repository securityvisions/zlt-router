#!/bin/sh
# dns-ensure.sh — keep DNS proxied + ad-blocked across node rotation and
# fail-open. When PassWall is enabled its xray/chinadns-ng pipeline owns DNS;
# when fail-open drops PassWall, dnsmasq would fall back to the ISP's plain
# resolvers (a DNS leak). This ensures the encrypted DoH stub is dnsmasq's
# upstream in that state and that no stub override lingers when PassWall is
# back. Minute cron, idempotent.

STUB="127.0.0.1#5053"   # https-dns-proxy DoH stub
DNS_EVENT_STATE="${DNS_EVENT_STATE:-/tmp/dns-event.state}"
DNS_EVENT_COOLDOWN_S="${DNS_EVENT_COOLDOWN_S:-3600}"
HN_LIB="${HN_LIB:-/root/hnlib.sh}"
[ -f "$HN_LIB" ] && . "$HN_LIB"

# dn_decision <passwall_enabled> <stub_ok> — pure: which upstream dnsmasq
# should use. passwall | encrypted | none.
dn_decision() {
    [ "$1" = "1" ] && { echo "passwall"; return; }
    [ "$2" = "1" ] && { echo "encrypted"; return; }
    echo "none"
}

dn_stub_ok() {
    [ -x /etc/init.d/https-dns-proxy ] && /etc/init.d/https-dns-proxy running 2>/dev/null
}

dn_pw_enabled() {
    [ "$(uci -q get passwall.@global[0].enabled 2>/dev/null)" = "1" ] && echo 1 || echo 0
}

dn_apply() {
    local d stub_has
    d=$(dn_decision "$(dn_pw_enabled)" "$(dn_stub_ok && echo 1 || echo 0)")
    stub_has=$(uci -q get dhcp.@dnsmasq[0].server 2>/dev/null | grep -qx "$STUB" && echo 1 || echo 0)
    case "$d" in
        passwall)
            if [ "$stub_has" = "1" ]; then
                uci -q del_list dhcp.@dnsmasq[0].server="$STUB"
                uci commit dhcp
                /etc/init.d/dnsmasq restart >/dev/null 2>&1 || true
                logger -t dns-ensure "removed stub override; PassWall DNS owns again"
            fi
            ;;
        encrypted)
            if [ "$stub_has" != "1" ]; then
                uci add_list dhcp.@dnsmasq[0].server="$STUB"
                uci commit dhcp
                /etc/init.d/dnsmasq restart >/dev/null 2>&1 || true
                logger -t dns-ensure "fail-open DNS: encrypted stub ($STUB)"
            fi
            ;;
        *) logger -t dns-ensure "no DoH stub available; DNS may leak during fail-open"
           if hn_cooldown_ok "$DNS_EVENT_STATE" "$DNS_EVENT_COOLDOWN_S" leak; then
               hn_cooldown_note "$DNS_EVENT_STATE" leak
               hn_event_record dns_unhealthy "no DoH stub available; DNS may leak during fail-open" dns-ensure >/dev/null 2>&1 || true
           fi ;;
    esac
    echo "$d"
}

case "${1:-}" in
    --decision) dn_decision "$2" "$3" ;;
    *) dn_apply ;;
esac
