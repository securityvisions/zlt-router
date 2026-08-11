#!/bin/sh
# Xirouter hourly telemetry snapshot — the app's usage/balance history source.
# Appends  ts|total_gb|balance_gb|proxy_state  to /etc/telemetry/hourly.log
# Cron (Iran time):  0 * * * *  /root/snap.sh
LOG="${RA_TELEMETRY_LOG:-/etc/telemetry/hourly.log}"
mkdir -p "$(dirname "$LOG")" 2>/dev/null

total=$(/usr/sbin/nlbw -c json -g mac 2>/dev/null | jq -r '[.data[] | .[2] + .[4]] | add // 0')
[ -z "$total" ] && total=0
total=$(awk -v b="$total" 'BEGIN{printf "%.3f", b/1073741824}')

balance=$(sed -n 's/Main: [0-9]* GB · \([0-9.]*\) GB left.*/\1/p' /tmp/balance_report 2>/dev/null)

proxy=down
code=$(curl -sS -m 5 --socks5 127.0.0.1:1070 -o /dev/null -w '%{http_code}' \
    https://www.gstatic.com/generate_204 2>/dev/null)
[ "$code" = "204" ] && proxy=up

echo "$(date '+%F %H:%M')|$total|${balance}|$proxy" >> "$LOG"
# prune to a year of hourly rows (8760)
tail -n 8760 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
