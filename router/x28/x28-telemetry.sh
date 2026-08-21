#!/bin/sh
# x28-telemetry.sh — hourly telemetry + history for dashboard/app charts.
# Appends ts|total_gb|balance_gb|proxy_state|operator|rsrp|temp|load to
# /data/proxy/usage/telemetry.log (the Telemetry log), procd hourly.
# Canonical copy: router/x28/x28-telemetry.sh — deploys to /data/proxy/x28-telemetry.sh
TELEM=/data/proxy/usage/telemetry.log
mkdir -p "$(dirname "$TELEM")"

telemetry_row() {
    local ts total_gb op rsrp temp load proxy
    ts=$(date +%FT%T 2>/dev/null)
    # WAN totals from modem (rxBytes)
    total_gb=$(sh /data/proxy/linkstate.sh 2>/dev/null | sed -n 's/^flow_dl=//p' | head -1)
    [ -z "$total_gb" ] && total_gb="?"
    op=$(sh /data/proxy/linkstate.sh 2>/dev/null | sed -n 's/^operator=//p' | head -1)
    rsrp=$(sh /data/proxy/linkstate.sh 2>/dev/null | sed -n 's/^rsrp=//p' | head -1)
    temp=$(sh /data/proxy/x28-thermal.sh read 2>/dev/null | tr -d ' \n')
    load=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null)
    proxy=$(curl -s -m 5 http://127.0.0.1:9090/proxies/auto 2>/dev/null | grep -o '"now":"[^"]*"' | cut -d'"' -f4)
    [ -z "$proxy" ] && proxy="?"
    printf '%s|%s|%s|%s|%s|%s|%s\n' "$ts" "$total_gb" "?" "$proxy" "${op:-?}" "${rsrp:-?}" "${temp:-?}|$load"
}

row=$(telemetry_row)
echo "$row" >> "$TELEM" 2>/dev/null
# keep last 5000 rows
[ "$(wc -l < "$TELEM" 2>/dev/null)" -gt 5000 ] && tail -n 4000 "$TELEM" > "$TELEM.t" 2>/dev/null && mv "$TELEM.t" "$TELEM"
echo "$row"
