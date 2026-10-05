#!/bin/sh
# /root/billing.sh — Deep Billing & Cost Serialization Engine
# Single source of truth for:
# - Rate resolution (Full vs Friday discounts)
# - Cost calculation & rounding in Toman
# - Direct serialization to JSON (for Router API) or Aligned Text Table (for Telegram bot)

BILLING_CONF="${BILLING_CONF:-${RA_BILLING_CONF:-/etc/billing.conf}}"

# Load dependencies
HERE_BIL="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ -f "$HERE_BIL/hnlib.sh" ]; then
    . "$HERE_BIL/hnlib.sh"
elif [ -f "/root/hnlib.sh" ]; then
    . "/root/hnlib.sh"
fi

billing_conf_val() {
    local key="$1" file="${2:-$BILLING_CONF}"
    [ -f "$file" ] || return 0
    sed -n "s/^${key}=[[:space:]]*//p" "$file" 2>/dev/null | head -1 | tr -d '"\r'
}

billing_rates() { # outputs: rate_full|rate_friday|round
    local rf rfr rnd
    rf=$(billing_conf_val RATE_FULL_TOMAN)
    [ -z "$rf" ] && rf=7700
    rfr=$(billing_conf_val RATE_FRIDAY_TOMAN)
    [ -z "$rfr" ] && rfr=4620
    rnd=$(billing_conf_val ROUND)
    [ -z "$rnd" ] && rnd=1000
    echo "$rf|$rfr|$rnd"
}

billing_rate_for() { # <friday: yes|no>
    local is_fri="${1:-no}" rates rf rfr rnd
    rates=$(billing_rates)
    rf=${rates%%|*}; rest=${rates#*|}
    rfr=${rest%%|*}; rnd=${rest#*|}
    if [ "$is_fri" = "yes" ]; then echo "$rfr"; else echo "$rf"; fi
}

# Stream processors (stdin: name|mac|bytes)
billing_stream_to_json() { # <friday: yes|no> <rate_full> <rate_friday> <round> [period_tag]
    local friday="${1:-no}" rf="${2:-7700}" rfr="${3:-4620}" rnd="${4:-1000}" period="${5:-}"
    local rate rows="" first=1 total_gb=0 total_toman=0 tag name mac gb toman share res
    if [ "$friday" = "yes" ]; then rate="$rfr"; else rate="$rf"; fi

    res=$(hn_cost_table "$rate" "$rnd")
    while IFS='|' read -r tag name mac gb toman share; do
        case "$tag" in
            ROW)
                if [ "$first" = 1 ]; then first=0; else rows="$rows,"; fi
                rows="$rows{\"name\":\"$name\",\"mac\":\"$mac\",\"gb\":$gb,\"toman\":$toman,\"share\":$share}"
                ;;
            TOTAL)
                total_gb="$name"
                total_toman="$mac"
                ;;
        esac
    done <<EOF
$res
EOF

    local is_fri_bool="false"
    [ "$friday" = "yes" ] && is_fri_bool="true"

    if [ -n "$period" ]; then
        echo "{\"period\":\"$period\",\"friday\":$is_fri_bool,\"rate_full\":$rf,\"rate_friday\":$rfr,\"rows\":[$rows],\"total_gb\":${total_gb:-0},\"total_toman\":${total_toman:-0}}"
    else
        echo "{\"friday\":$is_fri_bool,\"rate_full\":$rf,\"rate_friday\":$rfr,\"rows\":[$rows],\"total_gb\":${total_gb:-0},\"total_toman\":${total_toman:-0}}"
    fi
}

billing_stream_to_text() { # <friday: yes|no> <rate> <round> <header_label>
    local friday="${1:-no}" rate="${2:-7700}" rnd="${3:-1000}" label="${4:-Usage & cost}"
    local table
    table=$(hn_cost_table "$rate" "$rnd" | awk -F'|' '
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
    ')
    printf "📊 %s — Friday: %s\n\n%s\n" "$label" "$friday" "$table"
}

# High-level rendering engine
billing_render() { # <format: json|text> <period: today|month> [friday: yes|no] [month_ym]
    local format="$1" period="$2" friday="${3:-no}" ym="${4:-$(date +%Y-%m)}"
    local rates rf rfr rnd rate data label
    rates=$(billing_rates)
    rf=${rates%%|*}; rest=${rates#*|}
    rfr=${rest%%|*}; rnd=${rest#*|}
    if [ "$friday" = "yes" ]; then rate="$rfr"; else rate="$rf"; fi

    if [ "$period" = "today" ]; then
        label="Today's usage & cost"
        if command -v ra_usage_today >/dev/null 2>&1; then
            data=$(ra_usage_today | while IFS='|' read -r name meta bytes; do
                [ -z "$name" ] && continue
                case "$meta" in *:*) mac="$meta";; *) mac="";; esac
                if command -v ra_is_excluded_mac >/dev/null 2>&1 && ra_is_excluded_mac "$mac"; then continue; fi
                echo "$name|$mac|${bytes:-0}"
            done)
        elif [ -x /root/usage.sh ]; then
            data=$(/root/usage.sh --today 2>/dev/null)
        fi

        if [ "$format" = "json" ]; then
            echo "$data" | billing_stream_to_json "$friday" "$rf" "$rfr" "$rnd"
        else
            echo "$data" | billing_stream_to_text "$friday" "$rate" "$rnd" "$label"
        fi
    elif [ "$period" = "month" ]; then
        label="Monthly bill (${ym})"
        if command -v ra_usage_month_rows >/dev/null 2>&1; then
            data=$(ra_usage_month_rows "$ym" | while IFS='|' read -r key bytes; do
                [ -z "$key" ] && continue
                case "$key" in *:*) mac="$key";; *) mac="";; esac
                if command -v ra_is_excluded_mac >/dev/null 2>&1 && ra_is_excluded_mac "$mac"; then continue; fi
                name=""
                if command -v dev_reg_name >/dev/null 2>&1; then
                    name=$(dev_reg_name "$key")
                elif command -v ra_name_for_key >/dev/null 2>&1; then
                    name=$(ra_name_for_key "$key")
                fi
                if [ -z "$name" ]; then
                    case "$key" in *:*) name="Unknown-$(echo "$key" | cut -c1-8)";; *) name="$key";; esac
                fi
                echo "$name|$mac|$bytes"
            done)
        elif [ -x /root/usage.sh ]; then
            data=$(/root/usage.sh --month "$ym" 2>/dev/null)
        fi

        if [ "$format" = "json" ]; then
            echo "$data" | billing_stream_to_json "$friday" "$rf" "$rfr" "$rnd" "$ym"
        else
            echo "$data" | billing_stream_to_text "$friday" "$rate" "$rnd" "$label"
        fi
    fi
}

# CLI dispatcher — only execute when invoked directly as a script
case "${0##*/}" in
    billing.sh)
        case "${1:-}" in
            --today)
                fri="${2:-$(billing_conf_val LAST_FRIDAY)}"
                [ -z "$fri" ] && fri="no"
                billing_render text today "$fri"
                ;;
            --month)
                fri="${2:-$(billing_conf_val LAST_FRIDAY)}"
                [ -z "$fri" ] && fri="no"
                ym="${3:-$(date +%Y-%m)}"
                billing_render text month "$fri" "$ym"
                ;;
            --json-today)
                fri="${2:-no}"
                billing_render json today "$fri"
                ;;
            --json-month)
                fri="${2:-no}"
                ym="${3:-$(date +%Y-%m)}"
                billing_render json month "$fri" "$ym"
                ;;
            *)
                if [ "$#" -gt 0 ]; then
                    echo "usage: $0 {--today [yes|no]|--month [yes|no] [YYYY-MM]|--json-today [yes|no]|--json-month [yes|no] [YYYY-MM]}" >&2
                fi
                ;;
        esac
        ;;
esac
