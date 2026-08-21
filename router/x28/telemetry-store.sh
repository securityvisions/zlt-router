#!/bin/sh
# telemetry-store.sh — single history seam for Link + Probe + thermal.
# Replaces two logs (/etc/telemetry/hourly.log vs /data/.../telemetry.log) with
# one TelemetryStore.append(row) + prune + qualitySeries. Versioned schema.
# Canonical copy: router/x28/telemetry-store.sh — deploys to /data/proxy/telemetry-store.sh
TELEMETRY_LOG="${TELEMETRY_LOG:-/data/proxy/usage/telemetry.log}"
TELEMETRY_MAX="${TELEMETRY_MAX:-5000}"

# telemetry_append <row> — row is already formatted ts|... (from hn_telemetry_row or x28-telemetry.sh)
telemetry_append() {
    printf '%s\n' "$1" >> "$TELEMETRY_LOG" 2>/dev/null
    [ "$(wc -l < "$TELEMETRY_LOG" 2>/dev/null)" -gt "$TELEMETRY_MAX" ] && tail -n 4000 "$TELEMETRY_LOG" > "$TELEMETRY_LOG.t" 2>/dev/null && mv "$TELEMETRY_LOG.t" "$TELEMETRY_LOG"
}

# telemetry_prune [max] — keep last N rows
telemetry_prune() {
    local max="${1:-$TELEMETRY_MAX}"
    [ "$(wc -l < "$TELEMETRY_LOG" 2>/dev/null)" -gt "$max" ] && tail -n "$max" "$TELEMETRY_LOG" > "$TELEMETRY_LOG.t" 2>/dev/null && mv "$TELEMETRY_LOG.t" "$TELEMETRY_LOG"
}

# telemetry_series [hours] — last N hourly rows, oldest first (for QualityChart)
telemetry_series() {
    local hours="${1:-24}"
    tail -n "$hours" "$TELEMETRY_LOG" 2>/dev/null
}
