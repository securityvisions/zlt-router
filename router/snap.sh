#!/bin/sh
# Xirouter hourly telemetry snapshot — the app's usage/balance history source.
# Appends  ts|total_gb|balance_gb|proxy_state  to /etc/telemetry/hourly.log
# Cron (Iran time):  0 * * * *  /root/snap.sh
LOG="${RA_TELEMETRY_LOG:-/etc/telemetry/hourly.log}"
mkdir -p "$(dirname "$LOG")" 2>/dev/null
. /root/hnlib.sh 2>/dev/null

total=$(hn_sys_nlbw_total)
[ -z "$total" ] && total=0
total=$(awk -v b="$total" 'BEGIN{printf "%.3f", b/1073741824}')

balance=$(hn_balance_fields | sed -n 's/^remain=//p')

proxy=down
state=$(hn_sys_proxy_state)
[ "${state%%|*}" = "up" ] && proxy=up

echo "$(date '+%F %H:%M')|$total|${balance}|$proxy" >> "$LOG"
# prune to a year of hourly rows (8760)
tail -n 8760 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
