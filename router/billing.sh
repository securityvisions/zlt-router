#!/bin/sh
# Cost report in Toman (rounded) — the bot's text table for /cost, /bill and the
# monthly report. The pricing math lives in hnlib.sh (one implementation shared
# with the Router API); this script only formats its ROW/TOTAL lines into the
# aligned text table.
# input lines: name|mac|bytes  (same shape the Router API prices)
. /etc/billing.conf 2>/dev/null
. /root/hnlib.sh 2>/dev/null

rate_for() {  # rate_for <friday> — the active per-GB rate
    if [ "$1" = "yes" ]; then echo "${RATE_FRIDAY_TOMAN:-4620}"; else echo "${RATE_FULL_TOMAN:-7700}"; fi
}

format_cost_table() {  # stdin: ROW|TOTAL lines from hn_cost_table -> aligned text
    awk -F'|' '
        function cfmt(n, r, s) {
            s=sprintf("%d", n); r="";
            while (length(s) > 3) { r="," substr(s, length(s)-2) r; s=substr(s,1,length(s)-3) }
            return s r
        }
        $1=="ROW" {
            rows++;
            printf "%-22s %8.2f GB  %12s T  %3d%%\n", $2, $4+0, cfmt($5+0), int($6+0.5)
        }
        $1=="TOTAL" { ttom=$3 }
        END {
            if (!rows) { print "No usage data yet"; exit }
            printf "%-22s %8s     %12s T\n", "TOTAL", "", cfmt(ttom)
        }
    '
}

case "$1" in
    --today)
        friday="${2:-$LAST_FRIDAY}"
        data=$(/root/usage.sh --today)
        label="Today's usage & cost"
        if [ -z "$data" ]; then
            data=$(/root/usage.sh --raw)
            s=$(ls /etc/nlbwmon-v2/*.db.gz 2>/dev/null | head -1)
            if [ -n "$s" ]; then
                s=$(basename "$s" .db.gz)
                label="Usage & cost since ${s:0:4}-${s:4:2}-${s:6:2}"
            else
                label="Current period usage & cost"
            fi
        fi
        {
            echo "📊 ${label} — Friday: ${friday}"
            echo ""
            echo "$data" | hn_cost_table "$(rate_for "$friday")" "${ROUND:-1000}" | format_cost_table
        }
        ;;
    --month)
        friday="${2:-$LAST_FRIDAY}"
        ym="${3:-$(date +%Y-%m)}"
        {
            echo "📊 Monthly bill (${ym}) — Friday: ${friday}"
            echo ""
            /root/usage.sh --month "$ym" | hn_cost_table "$(rate_for "$friday")" "${ROUND:-1000}" | format_cost_table
        }
        ;;
    *)
        echo "usage: $0 {--today [yes|no]|--month [yes|no] [YYYY-MM]}" >&2
        ;;
esac