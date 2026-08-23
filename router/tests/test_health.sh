#!/bin/sh
# Unit tests: service-health probe, DNS health seam, Network Health Score
# (ADR-0005), and the quality-history reader — the router-side data foundation
# for the dashboard's Monitor phase. Pure functions, fixture-tested.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
HN_LIB="$HERE/../hnlib.sh"
[ -f "$HN_LIB" ] || HN_LIB="$HERE/hnlib.sh"
. "$HN_LIB"
[ -f "$(dirname "$0")/../health-model.sh" ] && . "$(dirname "$0")/../health-model.sh"

PASS=0; FAIL=0
assert_eq() {  # assert_eq <desc> <expected> <actual>
    if [ "$2" = "$3" ]; then
        PASS=$((PASS+1))
    else
        FAIL=$((FAIL+1))
        echo "FAIL - $1"
        printf '  expect: [%s]\n' "$2"
        printf '  actual: [%s]\n' "$3"
    fi
}
summary() {
    echo "PASS=$PASS FAIL=$FAIL"
    [ "$FAIL" -eq 0 ]
}

# ── service-health probe ──────────────────────────────────────────────────────
hn_svc_running() {  # fixture: only dnsmasq and uhttpd are up
    case "$1" in dnsmasq|uhttpd) return 0 ;; *) return 1 ;; esac
}
probe=$(hn_svc_probe "dnsmasq nlbwmon uhttpd rpcd")
assert_eq "probe: rows" "dnsmasq=up
nlbwmon=down
uhttpd=up
rpcd=down" "$probe"
assert_eq "probe: down list" "nlbwmon
rpcd" "$(hn_svc_down "$probe")"
assert_eq "svc penalty: 0 down" "0" "$(hn_svc_penalty 0)"
assert_eq "svc penalty: 1 down" "5" "$(hn_svc_penalty 1)"
assert_eq "svc penalty: 4 down" "20" "$(hn_svc_penalty 4)"
assert_eq "svc penalty: capped at 20" "20" "$(hn_svc_penalty 8)"

# ── DNS health seam ───────────────────────────────────────────────────────────
dns=$(hn_dns_stats "queries forwarded 8431, queries answered locally 2026
server on 127.0.0.1#53: queries sent 1000, retried or failed 5, avg time 3ms
server on 127.0.0.1#5053: queries sent 7431, retried or failed 12, avg time 28ms")
field() { printf '%s\n' "$dns" | sed -n "s/^$1=//p"; }
assert_eq "dns: forwarded" "8431" "$(field forwarded)"
assert_eq "dns: answered" "2026" "$(field answered)"
assert_eq "dns: retried failed" "17" "$(field retried_failed)"
assert_eq "dns: avg latency" "28" "$(field avg_latency_ms)"
assert_eq "dns: success rate" "0.9984" "$(field success_rate)"

dns=$(hn_dns_stats "queries forwarded 100, queries answered locally 20
server on 1: queries sent 120, retried or failed 30, avg time 5ms")
field() { printf '%s\n' "$dns" | sed -n "s/^$1=//p"; }
assert_eq "dns: bad success rate" "0.7500" "$(field success_rate)"

dns=$(hn_dns_stats "")
field() { printf '%s\n' "$dns" | sed -n "s/^$1=//p"; }
assert_eq "dns: empty stats forwarded 0" "0" "$(field forwarded)"
assert_eq "dns: empty success rate 1" "1" "$(field success_rate)"

assert_eq "dns success: pure calc" "0.9500" "$(hn_dns_success_rate 100 0 5)"
assert_eq "dns success: no queries" "1" "$(hn_dns_success_rate 0 0 0)"
assert_eq "dns penalty: healthy" "0" "$(hn_dns_penalty 0.99 50)"
assert_eq "dns penalty: low success" "15" "$(hn_dns_penalty 0.97 50)"
assert_eq "dns penalty: slow latency" "8" "$(hn_dns_penalty 0.99 250)"
assert_eq "dns penalty: both capped at 15" "15" "$(hn_dns_penalty 0.50 300)"
assert_eq "dns penalty: at 98% threshold ok" "0" "$(hn_dns_penalty 0.98 50)"

# ── Network Health Score (ADR-0005) ───────────────────────────────────────────
assert_eq "link penalty: ok" "0" "$(hn_health_link_penalty OK)"
assert_eq "link penalty: degraded" "30" "$(hn_health_link_penalty 'ALERT|degraded')"
assert_eq "proxy penalty: up" "0" "$(hn_health_proxy_penalty up)"
assert_eq "proxy penalty: down" "20" "$(hn_health_proxy_penalty down)"
assert_eq "fresh penalty: fresh" "0" "$(hn_health_freshness_penalty 60)"
assert_eq "fresh penalty: 11min" "5" "$(hn_health_freshness_penalty 660)"
assert_eq "fresh penalty: 2h" "15" "$(hn_health_freshness_penalty 7200)"

assert_eq "score: perfect" "100" "$(hn_health_score 0 0 0 0 0)"
assert_eq "score: link degraded" "70" "$(hn_health_score 30 0 0 0 0)"
assert_eq "score: everything degraded" "0" "$(hn_health_score 30 20 20 15 15)"
assert_eq "score: mixed" "55" "$(hn_health_score 30 0 5 0 10)"
assert_eq "score: cannot go negative" "0" "$(hn_health_score 30 20 20 15 25)"

assert_eq "band: 100" "Excellent" "$(hn_health_band 100)"
assert_eq "band: 90" "Excellent" "$(hn_health_band 90)"
assert_eq "band: 89" "Good" "$(hn_health_band 89)"
assert_eq "band: 75" "Good" "$(hn_health_band 75)"
assert_eq "band: 74" "Degraded" "$(hn_health_band 74)"
assert_eq "band: 50" "Degraded" "$(hn_health_band 50)"
assert_eq "band: 49" "Poor" "$(hn_health_band 49)"

summary
