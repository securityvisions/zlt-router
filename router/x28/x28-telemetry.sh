#!/bin/sh
# x28-telemetry.sh — hourly telemetry + history for dashboard/app charts.
# Appends via TelemetryStore (single history seam). Reads Link once per tick
# through the hnlib deep seam (hn_link_state) instead of 3 linkstate calls.
# Canonical copy: router/x28/x28-telemetry.sh — deploys to /data/proxy/x28-telemetry.sh

HN_LIB="${HN_LIB:-/data/proxy/hnlib.sh}"
[ -f "$HN_LIB" ] && . "$HN_LIB"

TELEM="${TELEMETRY_LOG:-/data/proxy/usage/telemetry.log}"
STORE_LIB="${TELEMETRY_STORE_LIB:-/data/proxy/telemetry-store.sh}"
[ -f "$STORE_LIB" ] && . "$STORE_LIB"
mkdir -p "$(dirname "$TELEM")"

telemetry_row() {
    local ts total_gb op rsrp temp load proxy fields
    ts=$(date +%FT%T 2>/dev/null)
    # one Link read per tick via the deep seam (was 3× linkstate.sh)
    if command -v hn_link_state >/dev/null 2>&1; then
        HN_LINK_STATE_CMD="timeout 20 sh /data/proxy/linkstate.sh" fields=$(hn_link_state)
        total_gb=$(printf '%s\n' "$fields" | sed -n 's/^flow_dl=//p' | head -1)
        op=$(printf '%s\n' "$fields" | sed -n 's/^operator=//p' | head -1)
        rsrp=$(printf '%s\n' "$fields" | sed -n 's/^rsrp=//p' | head -1)
    else
        # fallback: direct reader when hnlib is not yet deployed
        fields=$(sh /data/proxy/linkstate.sh 2>/dev/null)
        total_gb=$(printf '%s\n' "$fields" | sed -n 's/^flow_dl=//p' | head -1)
        op=$(printf '%s\n' "$fields" | sed -n 's/^operator=//p' | head -1)
        rsrp=$(printf '%s\n' "$fields" | sed -n 's/^rsrp=//p' | head -1)
    fi
    [ -z "$total_gb" ] && total_gb="?"
    temp=$(sh /data/proxy/x28-thermal.sh read 2>/dev/null | tr -d ' \n')
    load=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null)
    proxy=$(curl -s -m 5 http://127.0.0.1:9090/proxies/auto 2>/dev/null | grep -o '"now":"[^"]*"' | cut -d'"' -f4)
    [ -z "$proxy" ] && proxy="?"
    printf '%s|%s|%s|%s|%s|%s|%s\n' "$ts" "$total_gb" "?" "$proxy" "${op:-?}" "${rsrp:-?}" "${temp:-?}|$load"
}

row=$(telemetry_row)

# append through TelemetryStore when available, else inline
if command -v telemetry_append >/dev/null 2>&1; then
    telemetry_append "$row"
else
    echo "$row" >> "$TELEM" 2>/dev/null
    [ "$(wc -l < "$TELEM" 2>/dev/null)" -gt 5000 ] && tail -n 4000 "$TELEM" > "$TELEM.t" 2>/dev/null && mv "$TELEM.t" "$TELEM"
fi
# Budget guardian check (best-effort, no failure propagation)
sh /data/proxy/x28-budget.sh --check 2>/dev/null || true
echo "$row"
