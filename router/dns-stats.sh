#!/bin/sh
# dns-stats.sh — the DNS health seam on the router.
#
# Canonical copy lives in this repo (router/dns-stats.sh); deployed to the
# AX3000T as /root/dns-stats.sh. Reads dnsmasq's internal counters by sending
# it SIGUSR1 (it dumps query stats to the system log), captures the dump from
# logread, and prints the key=value block the health endpoint's DNS component
# consumes (hn_dns_stats input). The Router API /health endpoint runs this via
# ra_dns_stats (overridable in tests).

LOGREAD_BIN="${DNS_STATS_LOGREAD:-/sbin/logread}"
DNS_STATE="${DNS_STATS_STATE:-/tmp/dns-health.state}"
DNS_COOLDOWN_S="${DNS_STATS_COOLDOWN_S:-3600}"
HN_LIB="${HN_LIB:-/root/hnlib.sh}"
[ -f "$HN_LIB" ] && . "$HN_LIB"

# The PID file is a wildcard path on OpenWrt (dnsmasq.cfgNNNNNN.pid).
pid=$(ls ${DNS_STATS_PID:-/var/run/dnsmasq/dnsmasq.*.pid} 2>/dev/null | head -1 | xargs cat 2>/dev/null)
[ -z "$pid" ] && exit 0

kill -USR1 "$pid" 2>/dev/null
sleep 1
dump=$($LOGREAD_BIN -e 40 2>/dev/null | sed -n '/queries forwarded\|queries answered locally\|retried or failed\|avg time/p' | tail -n 12)

[ -n "$dump" ] || exit 0
stats=$(hn_dns_stats "$dump")
echo "$stats"

# The dns_unhealthy event lives on the health seam, not the leak condition:
# success below 98% or latency over 200ms records it, cooldown-gated so a
# sustained outage logs once per hour instead of spamming.
success=$(printf '%s\n' "$stats" | sed -n 's/^success_rate=//p')
latency=$(printf '%s\n' "$stats" | sed -n 's/^avg_latency_ms=//p')
if { awk -v s="${success:-1}" 'BEGIN{ exit (s < 0.98) ? 0 : 1 }'; } 2>/dev/null ||
   { awk -v l="${latency:-0}" 'BEGIN{ exit (l > 200) ? 0 : 1 }'; } 2>/dev/null; then
    if hn_cooldown_ok "$DNS_STATE" "$DNS_COOLDOWN_S" unhealthy; then
        hn_cooldown_note "$DNS_STATE" unhealthy
        hn_event_record dns_unhealthy "DNS unhealthy: success=${success:-?} latency=${latency:-?}ms" dns-stats >/dev/null 2>&1 || true
    fi
fi
