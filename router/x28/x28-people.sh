#!/bin/sh
# x28-people.sh — per-person monthly usage in Jalali calendar.
# Usage: x28-people.sh [jalali-month]  (e.g., 1405-06) default = current Jalali month
# Env overrides for tests: USAGE_DIR, OWNERS_FILE, BILLING_CONF, HN_LIB, DATE_CMD
set -eu

USAGE_DIR="${USAGE_DIR:-/data/proxy/usage}"
OWNERS_FILE="${HN_OWNERS_FILE:-/data/proxy/owners.conf}"
BILLING_CONF="$USAGE_DIR/billing.conf"
HN_LIB="${HN_LIB:-/root/hnlib.sh}"
[ -f "$HN_LIB" ] || HN_LIB="/data/proxy/hnlib.sh"
[ -f "$HN_LIB" ] || HN_LIB="$(dirname "$0")/../hnlib.sh"
[ -f "$HN_LIB" ] && . "$HN_LIB" 2>/dev/null || true

RATE_FULL=7700
RATE_FRIDAY=4620
[ -r "$BILLING_CONF" ] && . "$BILLING_CONF" 2>/dev/null || true

jmonth="${1:-}"
if [ -z "$jmonth" ]; then
    greg_today=$(date +%F 2>/dev/null)
    jmonth=$(hn_greg_to_jalali "$greg_today" 2>/dev/null | cut -d- -f1,2)
    [ -z "$jmonth" ] && jmonth=$(date +%Y-%m 2>/dev/null)
fi
# Validate jmonth
case "$jmonth" in ????-??) ;; *) echo "Usage: $0 [jalali-month YYYY-MM]" >&2; exit 1 ;; esac

range=$(hn_jalali_month_range "$jmonth" 2>/dev/null)
if [ -z "$range" ]; then
    echo "Invalid Jalali month: $jmonth" >&2
    exit 1
fi
start_d=$(printf '%s' "$range" | cut -d' ' -f1)
end_d=$(printf '%s' "$range" | cut -d' ' -f2)
# Clamp end to today (don't count future days) — but keep future months intact
today=$(date +%F 2>/dev/null)
if [ "$start_d" \> "$today" ] 2>/dev/null; then
    : # future month, keep original range
elif [ "$end_d" \> "$today" ] 2>/dev/null; then
    end_d="$today"
fi
# Month label
jy=$(printf '%s' "$jmonth" | cut -d- -f1)
jm=$(printf '%s' "$jmonth" | cut -d- -f2 | sed 's/^0*//')
label=$(hn_jalali_month_label "$jm" 2>/dev/null || echo "")

# Collect per-person totals
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
AGG_RAW="$TMP/raw.tmp"
AGG="$TMP/agg"
: > "$AGG_RAW"

# Iterate over owners files in range
# owners files are $USAGE_DIR/owners/YYYY-MM-DD
if [ -d "$USAGE_DIR/owners" ]; then
    # generate date list from start_d to end_d inclusive
    cur="$start_d"
    while [ -n "$cur" ]; do
        # compare cur <= end_d (lexicographic works for YYYY-MM-DD)
        if [ "$cur" \> "$end_d" ] 2>/dev/null; then break; fi
        f="$USAGE_DIR/owners/$cur"
        if [ -f "$f" ]; then
            is_fri=$(date -d "$cur" +%u 2>/dev/null || echo 1)
            rate="$RATE_FULL"
            [ "$is_fri" = "5" ] && rate="$RATE_FRIDAY"
            while IFS='|' read -r person up down; do
                [ -z "$person" ] && continue
                bytes=$(( up + down ))
                cost=$(awk -v b="$bytes" -v r="$rate" 'BEGIN{printf "%.0f", b/1073741824*r}')
                printf '%s|%s|%s|%s\n' "$person" "$up" "$down" "$cost" >> "$AGG_RAW" 2>/dev/null || true
            done < "$f"
        fi
        # next day
        nxt=$(date -d "$cur +1 day" +%F 2>/dev/null || break)
        [ -z "$nxt" ] && break
        [ "$nxt" = "$cur" ] && break
        [ "$nxt" = "$start_d" ] && break
        cur="$nxt"
    done
    # Aggregate per person
    if [ -f "$AGG_RAW" ]; then
        awk -F'|' '{ up[$1]+=$2; down[$1]+=$3; cost[$1]+=$4; n[$1]++ } END { for(p in up) printf "%s|%s|%s|%s\n", p, up[p], down[p], cost[p] }' "$AGG_RAW" > "$AGG" 2>/dev/null
    fi
fi

if [ ! -s "$AGG" ]; then
    echo "👥 People — $jmonth${label:+ ($label)}"
    echo "──────────────"
    echo "range $start_d to $end_d"
    echo "(no usage data for this month yet)"
    exit 0
fi

total_bytes=$(awk -F'|' '{s+=$2+$3} END{print s+0}' "$AGG")
total_cost=$(awk -F'|' '{s+=$4} END{print s+0}' "$AGG")

echo "👥 People — $jmonth${label:+ ($label)}"
echo "──────────────"
echo "range $start_d to $end_d"
printf '%-12s %7s %9s\n' "person" "GB" "Toman"
# Sort by bytes descending
sort -t'|' -k2,2 -nr "$AGG" 2>/dev/null | while IFS='|' read -r person up down cost; do
    bytes=$(( up + down ))
    gb=$(awk -v b="$bytes" 'BEGIN{printf "%.2f", b/1073741824}')
    printf '%-12s %7s %9d\n' "$(printf '%s' "$person" | cut -c1-12)" "$gb" "$cost"
done
# total
total_gb=$(awk -v b="$total_bytes" 'BEGIN{printf "%.2f", b/1073741824}')
printf '%-12s %7s %9d\n' "TOTAL" "$total_gb" "$total_cost"
