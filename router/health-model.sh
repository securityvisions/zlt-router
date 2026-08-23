#!/bin/sh
# health-model.sh — Network Health Score compute engine (ADR-0005).
#
# Owns: health score computation, per-component penalties, service probe,
# DNS stats, quality decision/suspicion gate, throughput calc.

hn_mbps_calc() {
    awk -v b="$1" -v t="$2" 'BEGIN{ if (t>0) printf "%.2f", b*8/t/1000000; else print 0 }'
}
hn_q_decision() {
    local lat="$1" sample="$2" floor="${3:-10}" ceiling="${4:-2.0}"
    if [ -n "$sample" ] && [ "$sample" != "0" ]; then
        if awk -v s="$sample" -v f="$floor" 'BEGIN{ exit (s >= f) ? 0 : 1 }'; then
            echo "OK"; return
        else
            echo "ALERT|degraded"; return
        fi
    fi
    if [ -n "$lat" ] && [ "$lat" != "0" ]; then
        if awk -v l="$lat" -v c="$ceiling" 'BEGIN{ exit (l <= c) ? 0 : 1 }'; then
            echo "OK"
        else
            echo "ALERT|degraded"
        fi
        return
    fi
    echo "OK"
}
hn_q_suspicious() {
    local lat="$1" passive="$2" ceiling="${3:-2.0}" floor="${4:-10}"
    if [ -n "$passive" ] && [ "$passive" != "0" ]; then
        if awk -v p="$passive" -v f="$floor" 'BEGIN{ exit (p < f) ? 0 : 1 }'; then
            echo "1"; return
        fi
    fi
    if [ -n "$lat" ] && [ "$lat" != "0" ]; then
        if awk -v l="$lat" -v c="$ceiling" 'BEGIN{ exit (l >= c) ? 0 : 1 }'; then
            echo "1"; return
        fi
    fi
    echo "0"
}
hn_svc_running() {
    local svc="$1"
    case "$svc" in
        passwall) pgrep -f '/TCP.*SOCKS.json' >/dev/null 2>&1 ;;
        *) [ -x "/etc/init.d/$svc" ] && "/etc/init.d/$svc" running 2>/dev/null ;;
    esac
}
hn_svc_probe() {
    local list="${1:-$HN_SVC_LIST}" svc
    for svc in $list; do
        if hn_svc_running "$svc"; then echo "$svc=up"; else echo "$svc=down"; fi
    done
}
hn_svc_down() {
    printf '%s\n' "$1" | sed -n 's/=down$//p'
}
hn_svc_penalty() {
    local n="${1:-0}" p
    p=$(( n * 5 ))
    [ "$p" -gt 20 ] && p=20
    echo "$p"
}
hn_dns_success_rate() {
    local f="${1:-0}" a="${2:-0}" r="${3:-0}" total good
    total=$((f + a)); good=$((total - r))
    awk -v t="$total" -v g="$good" 'BEGIN{ if (t > 0) printf "%.4f", g/t; else print 1 }'
}
hn_dns_penalty() {
    local p=0
    awk -v s="${1:-1}" 'BEGIN{ if (s < 0.98) exit 1 }' && p=0 || p=15
    awk -v l="${2:-0}" 'BEGIN{ if (l > 200) exit 1 }' && : || p=$((p + 8))
    [ "$p" -gt 15 ] && p=15
    echo "$p"
}
hn_dns_stats() {
    local text="$1" f a r lat
    f=$(printf '%s\n' "$text" | sed -n 's/.*queries forwarded \([0-9]*\).*/\1/p' | head -1)
    a=$(printf '%s\n' "$text" | sed -n 's/.*queries answered locally \([0-9]*\).*/\1/p' | head -1)
    r=$(printf '%s\n' "$text" | sed -n 's/.*retried or failed \([0-9]*\).*/\1/p' | awk '{s+=$1} END{print s+0}')
    lat=$(printf '%s\n' "$text" | sed -n 's/.*avg time \([0-9]*\)ms.*/\1/p' | sort -n | tail -1)
    [ -z "$f" ] && f=0; [ -z "$a" ] && a=0; [ -z "$r" ] && r=0; [ -z "$lat" ] && lat=0
    echo "forwarded=$f"
    echo "answered=$a"
    echo "retried_failed=$r"
    echo "avg_latency_ms=$lat"
    echo "success_rate=$(hn_dns_success_rate "$f" "$a" "$r")"
}
hn_health_link_penalty() {
    case "$1" in
        *degraded*) echo 30 ;;
        *) echo 0 ;;
    esac
}
hn_health_proxy_penalty() {
    [ "$1" = "up" ] && echo 0 || echo 20
}
hn_health_freshness_penalty() {
    local age="${1:-0}"
    [ "$age" -gt 3600 ] && { echo 15; return; }
    [ "$age" -gt 600 ] && { echo 5; return; }
    echo 0
}
hn_health_score() {
    local total=0
    total=$(( total + ${1:-0} + ${2:-0} + ${3:-0} + ${4:-0} + ${5:-0} ))
    [ "$total" -gt 100 ] && total=100
    [ "$total" -lt 0 ] && total=0
    echo $((100 - total))
}
hn_health_band() {
    local s="${1:-0}"
    [ "$s" -ge 90 ] && { echo Excellent; return; }
    [ "$s" -ge 75 ] && { echo Good; return; }
    [ "$s" -ge 50 ] && { echo Degraded; return; }
    echo Poor
}
hn_quality_series() {
    local log="${1:-${HN_TELEMETRY_LOG:-/etc/telemetry/hourly.log}}" hours="${2:-24}" n
    n=$(( hours * 1 ))
    [ "$n" -lt 1 ] 2>/dev/null && n=24
    awk -F'|' '$1 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/ { print $1 "|" $5 "|" $6 "|" $7 }' "$log" 2>/dev/null |
        tail -n "$n"
}