#!/bin/sh
# dns-fix.sh — keep the X28's network path MATCHED to tunnel health.
# Runs at boot (rc.local), on net hotplug, after operator switches, and
# every watchdog cycle. Probes the full tunnel chain (SOCKS 1080 -> VPS
# egress) and configures two things accordingly:
#
#   DNS upstream:
#     tunnel — server=127.0.0.1#5353 (xray forwarder -> VPS): clean,
#              anti-poisoning DNS.
#     isp    — ISP resolvers: survive a dead VPS (poisoned for some foreign
#              domains, but the house stays online).
#
#   Transparent proxy (fail-open):
#     tunnel — X28_SPLIT redirects LAN TCP into xray (split routing).
#     isp    — a top RETURN rule bypasses the redirect so LAN TCP flows
#              DIRECT. Without this, a dead VPS funnels every international
#              connection (Google, Gmail, ...) into a black hole even
#              though direct connectivity works.
#
# Both directions self-heal: the next probe that succeeds restores the
# tunnel path automatically. Idempotent: rewrites/restarts dnsmasq only
# when the config actually changes; iptables edits are checked first.
#
# Canonical copy: router/x28/dns-fix.sh — deploys to /data/proxy/dns-fix.sh.
set -eu

ADBLOCK=/data/proxy/adblock/adblock.conf
CONF=/tmp/dnsmasq.conf
LOCK=/tmp/dns-fix.lock

# Serialize: rc.local, the net hotplug and the watchdog can all call this
# at boot — without the lock their appends interleave and mangle the file.
i=0
while ! mkdir "$LOCK" 2>/dev/null; do
    i=$((i+1)); [ "$i" -gt 30 ] && exit 0   # someone else is on it; they'll finish
    sleep 2
done
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

# Wait for dnsmasq + the proxy engine (mihomo) to be up
for i in 1 2 3 4 5 6 7 8 9 10; do
    [ -f "$CONF" ] && pidof mihomo >/dev/null 2>&1 && break
    sleep 2
done

# tunnel_ok — does the whole proxy chain (SOCKS -> VPS -> internet) answer?
# Uses ProbeService when deployed; falls back to inline probe.
tunnel_ok() {
    if [ -x /data/proxy/probe-service.sh ]; then
        sh /data/proxy/probe-service.sh check passwall >/dev/null 2>&1 && return 0 || return 1
    fi
    code=$(curl -s -m 8 -x socks5h://192.168.70.1:1080 -o /dev/null \
        -w '%{http_code}' https://www.instagram.com/ 2>/dev/null)
    [ "$code" = "200" ]
}

mode=tunnel
tunnel_ok || { sleep 2; tunnel_ok || mode=isp; }

# Fail-open the transparent proxy when the tunnel is dead: all traffic
# flows direct instead of into the black-holed VLESS tunnel. Reverted on
# the first healthy probe.
if [ "$mode" = "tunnel" ]; then
    iptables -t nat -D X28_SPLIT -j RETURN 2>/dev/null || true
else
    iptables -t nat -C X28_SPLIT -j RETURN 2>/dev/null || \
        iptables -t nat -I X28_SPLIT 1 -j RETURN 2>/dev/null || true
fi

before=$(md5sum "$CONF" 2>/dev/null | cut -d' ' -f1)

# Strip our upstream lines (tunnel + isp + no-resolv + empty strays the
# boot race once produced), keep vendor config
sed -i '\|^server=127\.0\.0\.1#5353$|d; \|^no-resolv$|d; \|^server=$|d; \|^server=10\.[0-9.]*$|d; \|^server=217\.[0-9.]*$|d' "$CONF"

# Attach the selected upstream
if [ "$mode" = "tunnel" ]; then
    printf '\nserver=127.0.0.1#5353\nno-resolv\n' >> "$CONF"
else
    isp=$(awk '/^nameserver/{print $2; exit}' /tmp/resolv.conf 2>/dev/null)
    [ -n "$isp" ] || isp=10.201.112.252   # boot race: resolv.conf still empty
    printf '\nno-resolv\nserver=%s\n' "$isp" >> "$CONF"
fi

# Fix vendor DHCP pushing poisoned secondary DNS (114.114.114.114) — keep only X28
if grep -q "114\.114\.114\.114" "$CONF" 2>/dev/null; then
    sed -i 's|,114\.114\.114\.114||g' "$CONF"
fi

# Ad-blocking include in both modes (whenever the list exists)
if [ -f "$ADBLOCK" ]; then
    grep -q "^conf-file=$ADBLOCK$" "$CONF" 2>/dev/null || printf 'conf-file=%s\n' "$ADBLOCK" >> "$CONF"
else
    sed -i "\|^conf-file=$ADBLOCK\$|d" "$CONF"
fi

after=$(md5sum "$CONF" 2>/dev/null | cut -d' ' -f1)
if [ "$before" != "$after" ]; then
    pkill -9 dnsmasq 2>/dev/null || true
    sleep 1
    dnsmasq -C "$CONF" -x /tmp/dnsmasq.pid >/dev/null 2>&1 &
    sleep 2
    echo "dns-fix: mode=$mode (dnsmasq restarted)"
else
    echo "dns-fix: mode=$mode (no change)"
fi
