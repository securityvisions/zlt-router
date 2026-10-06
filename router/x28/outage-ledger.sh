#!/bin/sh
# outage-ledger.sh — Dedicated WAN Outage & SLA Ledger for X28 / AX3000T.
[ -n "${_OUTAGE_LEDGER_LOADED:-}" ] && return 0 2>/dev/null || true
_OUTAGE_LEDGER_LOADED=1
#
# Bounded Domain: Internet connectivity downtime tracking, MTTR calculation,
# and monthly Jalali SLA reports. Completely decoupled from billing and pricing.
#
# Ledger format: lines of "epoch|down" or "epoch|up" in $LEDGER.
#
# Interface:
#   outage-ledger.sh add-down
#   outage-ledger.sh add-up
#   outage-ledger.sh pair [ledger_file]
#   outage-ledger.sh total <jalali-month> [ledger_file]
#   outage-ledger.sh report [jalali-month]

LEDGER="${HN_OUTAGE_LEDGER:-/data/proxy/outage-ledger.log}"
CAL_LIB="${CAL_LIB:-/data/proxy/cal-lib.sh}"
if ! command -v hn_jalali_month_range >/dev/null 2>&1; then
    for _l in "$CAL_LIB" /root/cal-lib.sh /data/proxy/cal-lib.sh "$(dirname "$0")/cal-lib.sh" "$(dirname "$0")/../cal-lib.sh"; do
        [ -f "$_l" ] && . "$_l" && break
    done
fi

outage_now() {
    if [ -n "${HN_OUTAGE_NOW:-}" ]; then echo "$HN_OUTAGE_NOW"; else date +%s 2>/dev/null || echo 0; fi
}

outage_ensure() {
    mkdir -p "$(dirname "$LEDGER")" 2>/dev/null || true
    [ -f "$LEDGER" ] || : > "$LEDGER"
}

outage_add() {
    local kind="$1" last epoch
    outage_ensure
    last=$(tail -n 1 "$LEDGER" 2>/dev/null | cut -d'|' -f2 || true)
    [ "$last" = "$kind" ] && return 0
    epoch=$(outage_now)
    printf '%s|%s\n' "$epoch" "$kind" >> "$LEDGER" 2>/dev/null
    # Bound ledger to 5000 lines
    if [ "$(wc -l < "$LEDGER" 2>/dev/null || echo 0)" -gt 5000 ]; then
        tail -n 4000 "$LEDGER" > "$LEDGER.t" 2>/dev/null && mv "$LEDGER.t" "$LEDGER" || true
    fi
}

outage_pair() {
    local f="${1:-$LEDGER}"
    [ -f "$f" ] || return 0
    sort -t'|' -k1,1 -n "$f" 2>/dev/null | awk -F'|' '
        $2=="down" { down=$1; next }
        $2=="up" && down!="" { print down"|"$1"|"($1-down); down="" }
    '
}

outage_format_duration() {
    local s="${1:-0}" h m
    s=$(( s + 0 )) 2>/dev/null || s=0
    [ "$s" -lt 0 ] && s=0
    h=$(( s / 3600 )); m=$(( (s % 3600) / 60 ))
    if [ "$h" -gt 0 ] && [ "$m" -gt 0 ]; then echo "${h}h${m}m"
    elif [ "$h" -gt 0 ]; then echo "${h}h"
    else echo "${m}m"
    fi
}

outage_total() {
    local f="${1:-$LEDGER}" jmonth="${2:-}" now start_d end_d start_e end_e_next total range
    [ -f "$f" ] || { echo 0; return 0; }
    [ -n "$jmonth" ] || { echo 0; return 0; }
    range=$(hn_jalali_month_range "$jmonth" 2>/dev/null || true)
    [ -z "$range" ] && { echo 0; return 0; }
    start_d=$(printf '%s' "$range" | cut -d' ' -f1)
    end_d=$(printf '%s' "$range" | cut -d' ' -f2)
    [ -z "$start_d" ] || [ -z "$end_d" ] && { echo 0; return 0; }
    start_e=$(date -d "$start_d" +%s 2>/dev/null || date -d "$start_d 00:00:00" +%s 2>/dev/null || echo 0)
    end_e=$(date -d "$end_d" +%s 2>/dev/null || echo 0)
    end_e_next=$(( end_e + 86400 ))
    now=${HN_OUTAGE_NOW:-$(date +%s 2>/dev/null || echo 0)}
    [ -z "$now" ] && now=0
    sort -t'|' -k1,1 -n "$f" 2>/dev/null | awk -F'|' -v ms="$start_e" -v me="$end_e_next" -v now="$now" '
        $2=="down" { down=$1; next }
        $2=="up" && down!="" {
            up=$1
            s = (down>ms?down:ms)
            e = (up<me?up:me)
            if(e>s) total+=e-s
            down=""
            next
        }
        END {
            if(down!=""){
                up=now
                s=(down>ms?down:ms)
                e=(up<me?up:me)
                if(e>s) total+=e-s
            }
            print total+0
        }
    '
}

outage_report() {
    local jmonth="${1:-}" greg_today jal_today range total_s total_fmt pairs jy jm label_jm last down_e down_dur
    if [ -z "$jmonth" ]; then
        greg_today=$(date +%F 2>/dev/null || echo "2026-01-01")
        jal_today=$(hn_greg_to_jalali "$greg_today" 2>/dev/null | cut -d- -f1,2 || echo "1405-01")
        jmonth="$jal_today"
    fi
    jy=$(printf '%s' "$jmonth" | cut -d- -f1)
    jm=$(printf '%s' "$jmonth" | cut -d- -f2 | sed 's/^0*//')
    label_jm=$(hn_jalali_month_label "$jm" 2>/dev/null || echo "")
    total_s=$(outage_total "$LEDGER" "$jmonth" 2>/dev/null || echo 0)
    total_fmt=$(outage_format_duration "$total_s" 2>/dev/null || echo "0m")
    echo "📉 Outages — $jmonth${label_jm:+ ($label_jm)}"
    echo "──────────────"
    echo "total $total_fmt (${total_s}s)"
    if [ ! -f "$LEDGER" ] || [ ! -s "$LEDGER" ]; then
        echo "(no outages recorded yet)"
        return 0
    fi
    pairs=$(outage_pair "$LEDGER" 2>/dev/null || true)
    if [ -z "$pairs" ]; then
        last=$(tail -n 1 "$LEDGER" 2>/dev/null | cut -d'|' -f2 || true)
        if [ "$last" = "down" ]; then
            down_e=$(tail -n 1 "$LEDGER" 2>/dev/null | cut -d'|' -f1)
            down_dur=$(( $(outage_now) - down_e ))
            echo "⚠️ Currently down: $(outage_format_duration "$down_dur")"
        else
            echo "(no completed outage episodes)"
        fi
        return 0
    fi
    echo "$pairs" | tail -n 5 | while IFS='|' read -r d u dur; do
        printf '• %s -> %s (%s)\n' "$(date -d @"$d" '+%m-%d %H:%M' 2>/dev/null || echo "$d")" \
                                   "$(date -d @"$u" '+%H:%M' 2>/dev/null || echo "$u")" \
                                   "$(outage_format_duration "$dur")"
    done
}

# Compatibility aliases
hn_outage_pair() { outage_pair "${1:-$LEDGER}"; }
hn_outage_format_duration() { outage_format_duration "${1:-0}"; }
hn_outage_total() { outage_total "${1:-$LEDGER}" "${2:-}"; }

case "${0##*/}" in
    outage-ledger.sh|x28-outage-ledger.sh)
        case "${1:-}" in
            add-down) outage_add "down" ;;
            add-up)   outage_add "up" ;;
            pair)     outage_pair "${2:-$LEDGER}" ;;
            total)    outage_total "${3:-$LEDGER}" "${2:?jalali-month required}" ;;
            report)   outage_report "${2:-}" ;;
            *)
                echo "Usage: $0 {add-down|add-up|pair [file]|total <jmonth> [file]|report [jmonth]}" >&2
                exit 1
                ;;
        esac
        ;;
esac
