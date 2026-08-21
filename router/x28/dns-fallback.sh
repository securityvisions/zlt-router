#!/bin/sh
# dns-fallback.sh — BREAK-GLASS: keep DNS alive when the VPS tunnel is down.
# Swaps the dnsmasq upstream from the xray forwarder (127.0.0.1#5353, needs
# the VPS) to the ISP resolvers (poisoned for some domains, but alive).
# Restores general browsing when the proxy origin is dead; filtered apps
# stay down until the VPS returns.
# REVERT (back to clean tunnel DNS): sh /data/proxy/dns-fix.sh
set -eu

ISP_DNS=$(awk '/^nameserver/{print $2; exit}' /tmp/resolv.conf 2>/dev/null || echo 10.201.112.252)

for i in 1 2 3 4 5; do [ -f /tmp/dnsmasq.conf ] && break; sleep 2; done

# drop our tunnel upstream + adblock include (keep it simple + robust), set ISP
sed -i '\|^server=127\.0\.0\.1#5353$|d; \|^no-resolv$|d; \|^conf-file=/data/proxy/adblock/adblock\.conf$|d' /tmp/dnsmasq.conf
grep -q "^server=$ISP_DNS$" /tmp/dnsmasq.conf || printf '\nno-resolv\nserver=%s\n' "$ISP_DNS" >> /tmp/dnsmasq.conf

pkill -9 dnsmasq 2>/dev/null || true
sleep 1
dnsmasq -C /tmp/dnsmasq.conf -x /tmp/dnsmasq.pid >/dev/null 2>&1 &
sleep 2
echo "dns-fallback: dnsmasq on ISP DNS ($ISP_DNS) — revert with dns-fix.sh"
