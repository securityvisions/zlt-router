#!/bin/sh
# speedtest.sh — MCI link speed test with trend + degradation alert.
#
# Canonical copy lives in this repo (router/speedtest.sh); it deploys to the
# AX3000T as /root/speedtest.sh (cron nightly + /speedtest on demand). Runs a
# Cloudflare download, appends `ts|mbps` to /etc/telemetry/speed.log, and
# alerts when throughput drops below the floor (throttled by a state file).

ST_LOG="${ST_LOG:-/etc/telemetry/speed.log}"
ST_FLOOR="${ST_FLOOR:-10}"          # Mbps; below this -> degradation alert
ST_ALERT_COOLDOWN_S="${ST_ALERT_COOLDOWN_S:-86400}"
ST_STATE="${ST_STATE:-/tmp/speedtest.state}"
ST_MB="${ST_MB:-10}"

# st_calc <bytes> <seconds> — pure; prints mbps.
st_calc() {
    awk -v b="$1" -v t="$2" 'BEGIN{ if (t>0) printf "%.2f", b*8/t/1000000; else print 0 }'
}

# st_measure <mb> — download <mb> from Cloudflare; prints "mbps" or fails
# (retries once; zero bytes counts as failure so a dead window never records 0).
st_measure() {
    local mb="${1:-$ST_MB}" res try=1 size time
    while [ "$try" -le 2 ]; do
        res=$(curl -s -m 45 -o /dev/null -w '%{size_download}|%{time_total}' \
            "https://speed.cloudflare.com/__down?bytes=$((mb * 1000000))" 2>/dev/null)
        size=${res%%|*}; time=${res#*|}
        if [ -n "$size" ] && [ "$size" -gt 0 ] 2>/dev/null && [ -n "$time" ] && [ "$time" != "0" ]; then
            st_calc "$size" "$time"
            return 0
        fi
        try=$((try + 1))
    done
    return 1
}

# st_decision <mbps> <floor> — pure; prints OK | ALERT|slow.
st_decision() {
    local mbps="$1" floor="${2:-$ST_FLOOR}"
    awk -v m="$mbps" -v f="$floor" 'BEGIN{ exit !(m < f) }' && echo "ALERT|slow" || echo "OK"
}

# st_record <mbps> — append to the trend log, keep the tail.
st_record() {
    echo "$(date '+%Y-%m-%d %H:%M')|$1" >> "$ST_LOG"
    tail -n 200 "$ST_LOG" > "$ST_LOG.tmp" 2>/dev/null && mv "$ST_LOG.tmp" "$ST_LOG" 2>/dev/null
}

st_cooldown_ok() {
    local now last
    now=$(date +%s)
    last=$(sed -n 's/^alert //p' "$ST_STATE" 2>/dev/null | tail -1)
    [ -z "$last" ] && return 0
    [ $((now - last)) -ge "$ST_ALERT_COOLDOWN_S" ]
}

main() {
    local mbps decision
    mbps=$(st_measure) || { echo "speedtest: measure failed" >&2; exit 1; }
    st_record "$mbps"
    decision=$(st_decision "$mbps")
    if [ "$decision" = "ALERT|slow" ] && st_cooldown_ok; then
        echo "alert $(date +%s)" >> "$ST_STATE" 2>/dev/null
        [ -x /root/tg.sh ] && /root/tg.sh --text "⚠️ MCI link speed dropped to <b>${mbps} Mbps</b> (floor ${ST_FLOOR})." >/dev/null 2>&1
    fi
    echo "$mbps"
}

case "${1:-}" in
    --decision) st_decision "$2" "${3:-$ST_FLOOR}" ;;
    --calc) st_calc "$2" "$3" ;;
    *) main ;;
esac
