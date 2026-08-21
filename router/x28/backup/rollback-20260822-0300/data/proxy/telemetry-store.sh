#!/bin/sh
# telemetry-store.sh — single history seam for Link + Probe + thermal.
# One TelemetryStore replaces the two competing logs (/etc/telemetry/hourly.log
# on the AX3000T and /data/proxy/usage/telemetry.log on the X28) with one
# versioned schema, one pruning rule, and one series reader shared by
# hnlib.sh:hn_quality_series, the Router API /quality endpoint and web QualityChart.
#
# Schema v2 (trailing fields extend v1 so old `|` readers keep parsing):
#   ts|total_gb|balance_gb|proxy_state|operator|rsrp|temp|load|latency_s|passive_mbps|node
#
# Canonical copy: router/x28/telemetry-store.sh — deploys to /data/proxy/telemetry-store.sh

TELEMETRY_LOG="${TELEMETRY_LOG:-/data/proxy/usage/telemetry.log}"
TELEMETRY_MAX="${TELEMETRY_MAX:-5000}"

# telemetry_append <row> — append one already-formatted row + prune.
telemetry_append() {
    printf '%s\n' "$1" >> "$TELEMETRY_LOG" 2>/dev/null
    telemetry_prune
}

# telemetry_prune [max] — keep last N rows (single pruning rule).
telemetry_prune() {
    local max="${1:-$TELEMETRY_MAX}" n
    n=$(wc -l < "$TELEMETRY_LOG" 2>/dev/null)
    [ -n "$n" ] && [ "$n" -gt "$max" ] 2>/dev/null && {
        tail -n "$max" "$TELEMETRY_LOG" > "$TELEMETRY_LOG.t" 2>/dev/null &&
        mv "$TELEMETRY_LOG.t" "$TELEMETRY_LOG" 2>/dev/null
    }
    return 0
}

# telemetry_series [hours] — last N rows oldest-first (QualityChart feed).
telemetry_series() {
    local hours="${1:-24}"
    tail -n "${hours:-24}" "$TELEMETRY_LOG" 2>/dev/null
}

# telemetry_quality_series [hours] — "ts|latency|passive_mbps|node" projection,
# same shape as hnlib.sh:hn_quality_series so the Router API reads either store.
telemetry_quality_series() {
    local hours="${1:-24}"
    awk -F'|' '$1 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/ { print $1 "|" $9 "|" $10 "|" $11 }' \
        "$TELEMETRY_LOG" 2>/dev/null | tail -n "${hours:-24}"
}

# telemetry_last_age — seconds since the newest row (freshness penalty input).
telemetry_last_age() {
    local last ts t ep now
    last=$(tail -n 1 "$TELEMETRY_LOG" 2>/dev/null | cut -d'|' -f1)
    [ -z "$last" ] && { echo 999999; return; }
    ts=$(printf '%s' "$last" | cut -c1-19 | tr 'T' ' ')
    # busybox date: parse ISO-ish back to epoch
    ep=$(date -d "$ts" +%s 2>/dev/null || echo 0)
    now=$(date +%s)
    echo $((now - ep))
}
