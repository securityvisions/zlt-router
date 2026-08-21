#!/bin/sh
# Point the X28's dnsmasq at the xray DNS forwarder (clean DNS via VPS)
# and clear any poisoned cached answers. The vendor regenerates
# /tmp/dnsmasq.conf on network/operator changes, wiping our override and
# leaving poisoned answers cached. A FULL restart is required both to load
# the override AND to clear the cache (SIGHUP does neither reliably).
# Idempotent and safe to run repeatedly (brief DNS blip <2s).
set -eu

# Wait for dnsmasq + xray to be up
for i in 1 2 3 4 5 6 7 8 9 10; do
    [ -f /tmp/dnsmasq.conf ] && pgrep -f 'xray run' >/dev/null 2>&1 && break
    sleep 2
done

# Ensure the override is present
if ! grep -q 'server=127.0.0.1#5353' /tmp/dnsmasq.conf; then
    printf '\nserver=127.0.0.1#5353\nno-resolv\n' >> /tmp/dnsmasq.conf
fi

# Full restart: loads override AND clears poisoned DNS cache
pkill -9 dnsmasq 2>/dev/null || true
sleep 1
dnsmasq -C /tmp/dnsmasq.conf -x /tmp/dnsmasq.pid >/dev/null 2>&1 &
sleep 2
echo 'dns-fix: override ensured + dnsmasq restarted (cache cleared)'
