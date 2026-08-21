#!/bin/sh
# x28-thermal.sh — thermal sensor reader + overheat guard for the ZLT X28.
# Reads mtk-soc-temp (thermal_zone*/temp, millidegrees) and reports °C.
# Used by the procd service (60s sampling) and by x28-usage.sh / telemetry.
#
# Canonical copy: router/x28/x28-thermal.sh — deploys to /data/proxy/x28-thermal.sh
# Fixture: THERMAL_FIXTURE_DIR=/tmp/dir with files temp_0, temp_1 containing millidegrees.

THERMAL_THRESHOLD="${THERMAL_THRESHOLD:-75}"

# thermal_read — max temp °C across all thermal zones; empty if none.
thermal_read() {
    local dir="${THERMAL_FIXTURE_DIR:-/sys/class/thermal}"
    local max=""
    local f v c
    for f in "$dir"/thermal_zone*/temp "$dir"/temp_*; do
        [ -f "$f" ] || continue
        v=$(cat "$f" 2>/dev/null | tr -d ' \n\r')
        case "$v" in ''|*[!0-9]*) continue ;; esac
        c=$((v / 1000))
        if [ -z "$max" ] || [ "$c" -gt "$max" ]; then max="$c"; fi
    done
    printf '%s' "$max"
}

# thermal_overheated — exit 0 if temp > threshold.
thermal_overheated() {
    local t
    t=$(thermal_read)
    [ -n "$t" ] && [ "$t" -gt "$THERMAL_THRESHOLD" ]
}

# thermal_line — one telemetry row fragment: "temp=XX load=Y"
thermal_line() {
    local t load
    t=$(thermal_read)
    load=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null || echo "?")
    printf 'temp=%s load=%s' "${t:-?}" "$load"
}

case "${1:-read}" in
    read) thermal_read; echo ;;
    check) if thermal_overheated; then echo "overheated $(thermal_read)C"; exit 0; else echo "ok $(thermal_read)C"; exit 1; fi ;;
    line) thermal_line ;;
esac
