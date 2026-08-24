#!/bin/sh
# ledger-year.cgi — per-Jalali-month per-person GB for the year chart.
# GET params: ?year=1405 (default: current Jalali year).
# Reads the rollup store — 12 small files, no day-walking.
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo ""

HN_LIB="${HN_LIB:-/data/proxy/hnlib.sh}"
[ -f "$HN_LIB" ] || HN_LIB="/root/hnlib.sh"
[ -f "$HN_LIB" ] && . "$HN_LIB" 2>/dev/null || true

year=$(echo "${QUERY_STRING:-}" | sed -n "s/.*year=\([0-9]*\).*/\1/p")
[ -n "$year" ] || year=$(hn_greg_to_jalali "$(date +%F)" 2>/dev/null | cut -d- -f1)
case "$year" in 1[0-9][0-9][0-9]) ;; *) echo '{"error":"invalid year"}'; exit 0 ;; esac

JQ="${JQ_BIN:-/data/proxy/jq}"
ROLLUPS="${USAGE_DIR:-/data/proxy/usage}/rollups"

months_json=""
year_totals=""
m=1
while [ "$m" -le 12 ]; do
    jm=$(printf '%04d-%02d' "$year" "$m")
    f="$ROLLUPS/$jm.tsv"
    # person → GB for this month (TAB handoff: person names may contain spaces)
    per=$(awk -F'|' '{u[$2]+=$3} END{for(p in u) printf "%s\t%.2f\n",p,u[p]/1073741824}' "$f" 2>/dev/null)
    pobj=$(printf '%s' "$per" | "$JQ" -R -n '[inputs | split("\t") | {(.[0]): (.[1] | tonumber)}] | add // {}' 2>/dev/null)
    total=$(printf '%s' "$pobj" | "$JQ" -r '[.[]] | add // 0' 2>/dev/null)
    total=$(awk -v t="$total" 'BEGIN{printf "%.2f", t}')
    label=$(hn_jalali_month_label "$m" 2>/dev/null)
    [ -n "$pobj" ] || pobj='{}'
    mentry=$("$JQ" -n --arg m "$jm" --arg l "${label:-}" --argjson t "${total:-0}" --argjson p "$pobj" \
        '{month: $m, label: $l, total_gb: $t, persons: $p}' 2>/dev/null)
    months_json="$months_json$mentry
"
    # accumulate year totals: person → GB
    year_totals=$(printf '%s\n%s' "$year_totals" "$per" | awk -F'\t' '$1!=""{u[$1]+=$2} END{for(p in u) printf "%s\t%.2f\n",p,u[p]}')
    m=$((m + 1))
done

months_arr=$(printf '%s' "$months_json" | "$JQ" -sc '.' 2>/dev/null)
yobj=$(printf '%s' "$year_totals" | "$JQ" -R -n '[inputs | select(length>0) | split("\t") | {(.[0]): (.[1] | tonumber)}] | add // {}' 2>/dev/null)
[ -n "$months_arr" ] || months_arr='[]'
[ -n "$yobj" ] || yobj='{}'

"$JQ" -n --arg y "$year" --argjson months "$months_arr" --argjson persons "$yobj" \
    '{year: $y, months: $months, persons: $persons}'
