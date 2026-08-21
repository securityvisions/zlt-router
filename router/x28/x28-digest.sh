#!/bin/sh
# x28-digest.sh — Weekly Digest Card (Fri 20:00). Combines usage, Toman, top
# devices, outage minutes, balance+forecast, RSRP/operator/uptime into one Card.
# Env overrides for tests: USAGE_DIR, OUTAGE_LEDGER, BALANCE_REPORT, TELEMETRY_LOG, HN_LIB
set -eu

USAGE_DIR="${USAGE_DIR:-/data/proxy/usage}"
OUTAGE_LEDGER="${HN_OUTAGE_LEDGER:-/data/proxy/outage-ledger.log}"
BALANCE_REPORT="${BALANCE_REPORT:-/tmp/balance_report}"
TELEMETRY_LOG="${TELEMETRY_LOG:-/data/proxy/usage/telemetry.log}"
HN_LIB="${HN_LIB:-/root/hnlib.sh}"
[ -f "$HN_LIB" ] || HN_LIB="/data/proxy/hnlib.sh"
[ -f "$HN_LIB" ] || HN_LIB="$(dirname "$0")/../hnlib.sh"
[ -f "$HN_LIB" ] && . "$HN_LIB" 2>/dev/null || true

# Helpers
hr() { echo "──────────────────────"; }

# Week range: last 7 days inclusive (today and 6 days before)
week_start=$(date -d "6 days ago" +%F 2>/dev/null || date +%F)
week_end=$(date +%F 2>/dev/null)

# Usage: aggregate day files for last 7 days
usage_card=""
if [ -d "$USAGE_DIR/day" ]; then
    # Use x28-usage.sh week if available, else aggregate manually
    if [ -x "$USAGE_DIR/x28-usage.sh" ] || [ -x "$(dirname "$0")/x28-usage.sh" ]; then
        usage_bin="${USAGE_DIR}/x28-usage.sh"
        [ -x "$usage_bin" ] || usage_bin="$(dirname "$0")/x28-usage.sh"
        usage_card=$(USAGE_DIR="$USAGE_DIR" sh "$usage_bin" week 2>/dev/null || true)
    fi
    # Fallback: simple GB total
    if [ -z "$usage_card" ]; then
        total_b=$(awk -F'|' '!/^#/ {s+=$4+$5} END{print s+0}' "$USAGE_DIR"/day/* 2>/dev/null | awk '{s+=$1} END{print s+0}')
        gb=$(awk -v b="$total_b" 'BEGIN{printf "%.2f", b/1073741824}')
        usage_card="Usage week: ${gb} GB"
    fi
fi

# Top devices: from week usage
top_devices=""
if [ -d "$USAGE_DIR/day" ]; then
    # Aggregate per device for week
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT 2>/dev/null || true
    : > "$TMP/top.tmp"
    for d in $(seq 0 6); do
        day=$(date -d "$d days ago" +%F 2>/dev/null || date +%F)
        f="$USAGE_DIR/day/$day"
        [ -f "$f" ] || continue
        awk -F'|' '!/^#/ {print $3"|"$4+$5}' "$f" 2>/dev/null >> "$TMP/top.tmp" || true
    done
    if [ -s "$TMP/top.tmp" ]; then
        top_devices=$(awk -F'|' '{b[$1]+=$2} END{for(n in b) print n"|"b[n]}' "$TMP/top.tmp" | sort -t'|' -k2 -nr | head -n 3 | while IFS='|' read -r name bytes; do
            gb=$(awk -v b="$bytes" 'BEGIN{printf "%.2f", b/1073741824}'); printf '%-12s %s GB\n' "$name" "$gb"
        done)
    fi
    rm -rf "$TMP" 2>/dev/null || true
    trap - EXIT 2>/dev/null || true
fi

# Balance + forecast
balance_card=""
if [ -f "$BALANCE_REPORT" ]; then
    if command -v hn_balance_fields >/dev/null 2>&1; then
        fields=$(hn_balance_fields "$BALANCE_REPORT" 2>/dev/null || echo "available=0")
        remain=$(printf '%s\n' "$fields" | sed -n 's/^remain=//p' | head -1)
        quota=$(printf '%s\n' "$fields" | sed -n 's/^quota=//p' | head -1)
        pct=$(printf '%s\n' "$fields" | sed -n 's/^pct=//p' | head -1)
        if [ -n "$remain" ]; then
            balance_card="balance ${remain} GB${quota:+ / ${quota} GB}${pct:+ (${pct}%)}"
            # try budget card for forecast
            if [ -x "$(dirname "$0")/x28-budget.sh" ]; then
                budget_line=$(BALANCE_REPORT="$BALANCE_REPORT" sh "$(dirname "$0")/x28-budget.sh" --card 2>/dev/null | grep -E "exhaustion|drain" | head -1)
                [ -n "$budget_line" ] && balance_card="$balance_card
$budget_line"
            fi
        fi
    fi
fi

# Outage minutes this week
outage_week=""
if [ -f "$OUTAGE_LEDGER" ] && command -v hn_outage_pair >/dev/null 2>&1; then
    # Compute outage seconds in last 7 days via pairing overlap
    week_start_e=$(date -d "$week_start" +%s 2>/dev/null || echo 0)
    week_end_next=$(date -d "$week_end +1 day" +%s 2>/dev/null || echo 0)
    # If week_end_next is 0, use now
    [ "$week_end_next" -eq 0 ] && week_end_next=$(date +%s 2>/dev/null)
    total_s=$(sort -t'|' -k1,1 -n "$OUTAGE_LEDGER" 2>/dev/null | awk -F'|' -v ws="$week_start_e" -v we="$week_end_next" -v now="$(date +%s 2>/dev/null)" '
        $2=="down" { down=$1; next }
        $2=="up" && down!="" { up=$1; s=(down>ws?down:ws); e=(up<we?up:we); if(e>s) total+=e-s; down=""; next }
        END { if(down!=""){ up=now; s=(down>ws?down:ws); e=(up<we?up:we); if(e>s) total+=e-s } print total+0 }')
    outage_fmt=$(hn_outage_format_duration "$total_s" 2>/dev/null || echo "${total_s}s")
    outage_week="outages ${outage_fmt} this week"
fi

# Link quality: RSRP/operator/uptime
link_card=""
if command -v hn_link_state >/dev/null 2>&1; then
    fields=$(hn_link_state 2>/dev/null || true)
    op=$(printf '%s\n' "$fields" | sed -n 's/^operator=//p' | head -1)
    rsrp=$(printf '%s\n' "$fields" | sed -n 's/^rsrp=//p' | head -1)
    if [ -n "$op" ] || [ -n "$rsrp" ]; then
        link_card="link ${op:-?} RSRP ${rsrp:-?}"
    fi
fi
if [ -z "$link_card" ] && [ -x /data/proxy/x28-status.sh ]; then
    link_card=$(sh /data/proxy/x28-status.sh 2>/dev/null | head -1)
fi
if [ -z "$link_card" ]; then
    link_card="link —"
fi

# Build final card
echo "🧾 Weekly Digest"
hr
# Usage section
if [ -n "$usage_card" ]; then
    printf '%s\n' "$usage_card" | head -n 10
else
    echo "usage —"
fi
hr
if [ -n "$top_devices" ]; then
    echo "Top devices:"
    printf '%s\n' "$top_devices"
    hr
fi
if [ -n "$balance_card" ]; then
    printf '%s\n' "$balance_card"
    hr
fi
if [ -n "$outage_week" ]; then
    echo "$outage_week"
    hr
fi
printf '%s\n' "$link_card"
# Footer with week range
echo "week $week_start to $week_end"
