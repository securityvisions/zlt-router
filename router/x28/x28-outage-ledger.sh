#!/bin/sh
# x28-outage-ledger.sh — Outage Ledger (SLA) for the X28.
# Ledger: ${HN_OUTAGE_LEDGER:-/data/proxy/outage-ledger.log}  lines epoch|down or epoch|up
# Usage: x28-outage-ledger.sh add-down | add-up | report [jalali-month] | pair | total <jalali-month>
set -eu

LEDGER="${HN_OUTAGE_LEDGER:-/data/proxy/outage-ledger.log}"
HN_LIB="${HN_LIB:-/root/hnlib.sh}"
[ -f "$HN_LIB" ] || HN_LIB="/data/proxy/hnlib.sh"
[ -f "$HN_LIB" ] || HN_LIB="$(dirname "$0")/../hnlib.sh"
[ -f "$HN_LIB" ] && . "$HN_LIB"

now_epoch() {
    if [ -n "${HN_OUTAGE_NOW:-}" ]; then echo "$HN_OUTAGE_NOW"; else date +%s 2>/dev/null || echo 0; fi
}

ledger_ensure() {
    mkdir -p "$(dirname "$LEDGER")" 2>/dev/null || true
    [ -f "$LEDGER" ] || : > "$LEDGER"
}

add_kind() {
    local kind="$1" last
    ledger_ensure
    last=$(tail -n 1 "$LEDGER" 2>/dev/null | cut -d'|' -f2)
    [ "$last" = "$kind" ] && return 0
    # also check if file is empty or last is empty, allow
    epoch=$(now_epoch)
    printf '%s|%s\n' "$epoch" "$kind" >> "$LEDGER" 2>/dev/null
    # bound to 5000 lines
    [ "$(wc -l < "$LEDGER" 2>/dev/null)" -gt 5000 ] && tail -n 4000 "$LEDGER" > "$LEDGER.t" 2>/dev/null && mv "$LEDGER.t" "$LEDGER" || true
}

report_card() {
    local jmonth="${1:-}" greg_today jal_today range total_s total_fmt pairs
    if [ -z "$jmonth" ]; then
        greg_today=$(date +%F 2>/dev/null)
        jal_today=$(hn_greg_to_jalali "$greg_today" 2>/dev/null | cut -d- -f1,2)
        jmonth="$jal_today"
    fi
    [ -n "$jmonth" ] || jmonth=$(hn_greg_to_jalali "$(date +%F 2>/dev/null)" 2>/dev/null | cut -d- -f1,2)
    # month label
    jy=$(printf '%s' "$jmonth" | cut -d- -f1)
    jm=$(printf '%s' "$jmonth" | cut -d- -f2 | sed 's/^0*//')
    label_jm=$(hn_jalali_month_label "$jm" 2>/dev/null || echo "")
    total_s=$(hn_outage_total "$LEDGER" "$jmonth" 2>/dev/null || echo 0)
    total_fmt=$(hn_outage_format_duration "$total_s" 2>/dev/null || echo "0m")
    echo "📉 Outages — $jmonth${label_jm:+ ($label_jm)}"
    echo "──────────────"
    echo "total $total_fmt (${total_s}s)"
    if [ ! -f "$LEDGER" ] || [ ! -s "$LEDGER" ]; then
        echo "(no outages recorded yet)"
        return 0
    fi
    pairs=$(hn_outage_pair "$LEDGER" 2>/dev/null)
    if [ -z "$pairs" ]; then
        # check if currently down (open)
        last=$(tail -n 1 "$LEDGER" 2>/dev/null | cut -d'|' -f2)
        if [ "$last" = "down" ]; then
            down_e=$(tail -n 1 "$LEDGER" 2>/dev/null | cut -d'|' -f1)
            now=$(now_epoch)
            dur=$(( now - down_e ))
            fmt=$(hn_outage_format_duration "$dur" 2>/dev/null || echo "${dur}s")
            down_greg=$(date -d "@$down_e" +%F\ %H:%M 2>/dev/null || echo "$down_e")
            echo "open since $down_greg ($fmt ongoing)"
        else
            echo "(no completed outages)"
        fi
        return 0
    fi
    # Show recent 5 pairs, newest first
    echo "$pairs" | sort -t'|' -k1,1 -nr | head -n 5 | while IFS='|' read -r d u dur; do
        fmt=$(hn_outage_format_duration "$dur" 2>/dev/null || echo "${dur}s")
        d_str=$(date -d "@$d" +%F\ %H:%M 2>/dev/null || echo "$d")
        u_str=$(date -d "@$u" +%F\ %H:%M 2>/dev/null || echo "$u")
        echo "$d_str → $u_str ($fmt)"
    done
    # If open, show it
    last=$(tail -n 1 "$LEDGER" 2>/dev/null | cut -d'|' -f2)
    if [ "$last" = "down" ]; then
        down_e=$(tail -n 1 "$LEDGER" 2>/dev/null | cut -d'|' -f1)
        now=$(now_epoch)
        dur=$(( now - down_e ))
        fmt=$(hn_outage_format_duration "$dur" 2>/dev/null || echo "${dur}s")
        down_greg=$(date -d "@$down_e" +%F\ %H:%M 2>/dev/null || echo "$down_e")
        echo "open since $down_greg ($fmt ongoing)"
    fi
}

case "${1:-report}" in
    add-down) add_kind down ;;
    add-up) add_kind up ;;
    pair) hn_outage_pair "$LEDGER" ;;
    total) hn_outage_total "$LEDGER" "${2:-}" ;;
    report) report_card "${2:-}" ;;
    *) report_card "${1:-}" ;;
esac
