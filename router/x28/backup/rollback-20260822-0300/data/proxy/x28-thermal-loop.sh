#!/bin/sh
# x28-thermal-loop.sh — procd loop body for thermal guard.
# 60s sampling: logs temp|load|rsrp to /data/proxy/usage/telemetry.log and
# fires tg-notify.sh once per overheat episode (>75°C).
# Canonical copy: router/x28/x28-thermal-loop.sh — deploys alongside x28-thermal.sh
DIR=/data/proxy/usage
TELEM="$DIR/telemetry.log"
THERMAL_BIN=/data/proxy/x28-thermal.sh
ALERT_MARK="$DIR/.thermal-alerted"

mkdir -p "$DIR"
while :; do
    temp=$("$THERMAL_BIN" read 2>/dev/null | tr -d ' \n')
    load=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null)
    # Link RSRP best-effort
    rsrp=$(sh /data/proxy/linkstate.sh 2>/dev/null | sed -n 's/^rsrp=//p' | head -1)
    ts=$(date +%F\ %T)
    echo "$ts|temp=${temp:-?}|load=${load:-?}|rsrp=${rsrp:-?}" >> "$TELEM" 2>/dev/null
    # tail-trim telemetry (keep last 2000 lines)
    [ -f "$TELEM" ] && [ "$(wc -l < "$TELEM" 2>/dev/null)" -gt 2000 ] && tail -n 1500 "$TELEM" > "$TELEM.t" 2>/dev/null && mv "$TELEM.t" "$TELEM"
    if [ -n "$temp" ] && [ "$temp" -gt 75 ] 2>/dev/null; then
        if [ ! -f "$ALERT_MARK" ]; then
            status=$(sh /data/proxy/x28-status.sh 2>/dev/null | head -5)
            sh /data/proxy/tg-notify.sh "X28 overheat ${temp}C" "$status
Temp ${temp}C load $load RSRP ${rsrp:-?} dBm" 2>/dev/null || true
            touch "$ALERT_MARK"
        fi
    else
        rm -f "$ALERT_MARK"
    fi
    sleep 60
done
