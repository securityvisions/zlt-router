#!/bin/sh
# ledger-rules.sh — household domain rules.
#
# Owns: owner lookup (MAC→person), budget tier decision, bearer-bounce
# escalation, outage pairing/totals/duration formatting, and rescue-supervisor
# decision. All pure functions with explicit inputs.
#
# Depends on: cal-lib.sh (for hn_jalali_month_range in outage totals)

hn_budget_tier() {
    local remain="${1:-}" expiry="${2:-}" proj="${3:-}"
    # normalize empty to large sentinel
    [ -z "$remain" ] && remain=9999
    [ -z "$expiry" ] && expiry=9999
    [ -z "$proj" ] && proj=9999
    awk -v r="$remain" -v e="$expiry" -v p="$proj" '
    BEGIN{
        # exhausted first
        if (r+0 < 0.05) { print "exhausted"; exit }
        if (r+0 < 3 || e+0 < 3 || p+0 < 7) { print "urgent"; exit }
        if (r+0 < 10 || e+0 < 7 || p+0 < 14) { print "warn"; exit }
        print "ok"
    }'
}
hn_outage_pair() {
    local f="${1:-$HN_OUTAGE_LEDGER}"
    [ -f "$f" ] || return 0
    sort -t'|' -k1,1 -n "$f" 2>/dev/null | awk -F'|' '
        $2=="down" { down=$1; next }
        $2=="up" && down!="" { print down"|"$1"|"($1-down); down="" }
    '
}
hn_outage_format_duration() {
    local s="${1:-0}" h m
    s=$(( s + 0 )) 2>/dev/null || s=0
    [ "$s" -lt 0 ] && s=0
    h=$(( s / 3600 )); m=$(( (s % 3600) / 60 ))
    if [ "$h" -gt 0 ] && [ "$m" -gt 0 ]; then echo "${h}h${m}m"
    elif [ "$h" -gt 0 ]; then echo "${h}h"
    else echo "${m}m"
    fi
}
hn_outage_total() {
    local f="${1:-$HN_OUTAGE_LEDGER}" jmonth="${2:-}" now start_d end_d start_e end_e_next total
    [ -f "$f" ] || { echo 0; return 0; }
    [ -n "$jmonth" ] || { echo 0; return 0; }
    # month range via calendar module
    local range
    range=$(hn_jalali_month_range "$jmonth" 2>/dev/null)
    [ -z "$range" ] && { echo 0; return 0; }
    start_d=$(printf '%s' "$range" | cut -d' ' -f1)
    end_d=$(printf '%s' "$range" | cut -d' ' -f2)
    [ -z "$start_d" ] || [ -z "$end_d" ] && { echo 0; return 0; }
    start_e=$(date -d "$start_d" +%s 2>/dev/null || date -d "$start_d 00:00:00" +%s 2>/dev/null || echo 0)
    end_e=$(date -d "$end_d" +%s 2>/dev/null || echo 0)
    end_e_next=$(( end_e + 86400 ))
    now=${HN_OUTAGE_NOW:-$(date +%s 2>/dev/null)}
    [ -z "$now" ] && now=0
    sort -t'|' -k1,1 -n "$f" 2>/dev/null | awk -F'|' -v ms="$start_e" -v me="$end_e_next" -v now="$now" '
        $2=="down" { down=$1; next }
        $2=="up" && down!="" {
            up=$1
            # overlap [down,up) with [ms,me)
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
hn_owner_of() {
    local mac="${1:-}" f="${2:-$HN_OWNERS_FILE}" want line
    [ -n "$mac" ] || { echo ""; return 0; }
    want=$(printf '%s' "$mac" | tr 'A-Z' 'a-z')
    [ -f "$f" ] || { echo ""; return 0; }
    line=$(grep -i "^$(printf '%s' "$want" | sed 's/[][\.*^$]/\\&/g')|" "$f" 2>/dev/null | head -1)
    [ -z "$line" ] && { echo ""; return 0; }
    printf '%s' "$line" | cut -d'|' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}
hn_bounce_decide() {
    local r="${1:-0}" age="${2:-999999}" after="${3:-2}" cd="${4:-3600}"
    case "$r"   in *[!0-9]*) r=0      ;; esac
    case "$age" in *[!0-9]*) age=999999 ;; esac
    [ "$r" -ge "$after" ] && [ "$age" -ge "$cd" ] && { echo "yes"; return; }
    echo "no"
}