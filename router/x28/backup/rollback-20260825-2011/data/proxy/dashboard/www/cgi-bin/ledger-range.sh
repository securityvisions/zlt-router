#!/bin/sh
# ledger-range.cgi — aggregate owners-d between two Gregorian dates.
# GET params: ?from=YYYY-MM-DD&to=YYYY-MM-DD[&format=json|csv]
# Rows come from the ledger-store seam (rolled file wins; live-today fallback),
# so a range covering today never shows 0.0 GB before the midnight roll.

HN_LIB="${HN_LIB:-/data/proxy/hnlib.sh}"
[ -f "$HN_LIB" ] || HN_LIB="/root/hnlib.sh"
[ -f "$HN_LIB" ] && . "$HN_LIB" 2>/dev/null || true

# ledger-store: single aggregation seam (ledger_day_rows, dow_u, rate table)
for _ls in "$(dirname "$0")/../../ledger-store.sh" /data/proxy/ledger-store.sh /data/proxy/usage/ledger-store.sh; do
    [ -f "$_ls" ] && . "$_ls" && break
done 2>/dev/null
RATE_FULL="${RATE_FULL:-7700}"
RATE_FRIDAY="${RATE_FRIDAY:-4620}"

from=$(echo "${QUERY_STRING:-}" | sed -n "s/.*from=\([^&]*\).*/\1/p")
to=$(echo "${QUERY_STRING:-}" | sed -n "s/.*to=\([^&]*\).*/\1/p")
fmt=$(echo "${QUERY_STRING:-}" | sed -n "s/.*format=\([^&]*\).*/\1/p")
JQ="${JQ_BIN:-/data/proxy/jq}"

case "$from" in ??????????*) ;; *) echo "Content-Type: application/json"; echo "Access-Control-Allow-Origin: *"; echo ""; echo '{"error":"missing from date"}'; exit 0 ;; esac
case "$to" in ??????????*) ;; *) echo "Content-Type: application/json"; echo "Access-Control-Allow-Origin: *"; echo ""; echo '{"error":"missing to date"}'; exit 0 ;; esac

if [ "$fmt" = "csv" ]; then
    echo "Content-Type: text/csv; charset=utf-8"
    echo "Access-Control-Allow-Origin: *"
    echo "Content-Disposition: attachment; filename=\"ledger-${from}_${to}.csv\""
    echo ""
else
    echo "Content-Type: application/json"
    echo "Access-Control-Allow-Origin: *"
    echo ""
fi

OD="${USAGE_DIR:-/data/proxy/usage}/owners-d"
[ -d "$OD" ] || { [ "$fmt" = "csv" ] && exit 0; echo '{"error":"no owner data"}'; exit 0; }

jfrom=$(hn_greg_to_jalali "$from" 2>/dev/null)
jto=$(hn_greg_to_jalali "$to" 2>/dev/null)

tmpf=$(mktemp)
tmpd=$(mktemp)
cur="$from"
while [ -n "$cur" ]; do
    [ "$cur" \> "$to" ] 2>/dev/null && break
    is_fri=$(dow_u "$cur" 2>/dev/null)
    rate=$RATE_FULL; [ "$is_fri" = "5" ] && rate=$RATE_FRIDAY
    : > "$tmpd"
    ledger_day_rows "$cur" > "$tmpd" 2>/dev/null
    while IFS='|' read -r person mac up down; do
        [ -n "$person" ] || continue
        bytes=$(( ${up:-0} + ${down:-0} ))
        cost=$(awk -v b="$bytes" -v r="$rate" 'BEGIN{printf "%.0f", b/1073741824*r}')
        printf '%s\t%s\t%s\t%s\n' "$person" "$mac" "$bytes" "$cost" >> "$tmpf"
    done < "$tmpd"
    cur=$(greg_next "$cur")
done
rm -f "$tmpd"

if [ ! -s "$tmpf" ]; then
    rm -f "$tmpf"
    if [ "$fmt" = "csv" ]; then
        echo "person,gb,cost_toman"
        exit 0
    fi
    "$JQ" -n --arg jf "${jfrom:-}" --arg jt "${jto:-}" \
        '{entries: [], breakdown: [], jalali_from: $jf, jalali_to: $jt}'
    exit 0
fi

# CSV export: one row per person (GB, Toman), sorted by GB desc
if [ "$fmt" = "csv" ]; then
    echo "person,gb,cost_toman"
    sort "$tmpf" | awk -F'\t' '{u[$1]+=$3;c[$1]+=$4}
        END{for(p in u) printf "%s,%.2f,%.0f\n",p,u[p]/1073741824,c[p]}' "$tmpf" | sort -t, -k2,2 -nr
    rm -f "$tmpf"
    exit 0
fi

# aggregate per person (%.0f: busybox awk %d clamps at 2^31)
sort "$tmpf" | awk -F'\t' '{u[$1]+=$3;c[$1]+=$4}
    END{for(p in u) printf "{\"person\":\"%s\",\"bytes\":%.0f,\"cost\":%.0f}\n",p,u[p],c[p]}' "$tmpf" > "${tmpf}.agg"

# per-device breakdown
sort "$tmpf" | awk -F'\t' '{u[$1 "\t" $2]+=$3}
    END{for(k in u){split(k,a,"\t"); printf "{\"person\":\"%s\",\"mac\":\"%s\",\"bytes\":%.0f}\n",a[1],a[2],u[k]}}' "$tmpf" > "${tmpf}.dev"

# combine into single JSON
entries_json=$("$JQ" -sc '.' "${tmpf}.agg" 2>/dev/null)
dev_json=$("$JQ" -sc '.' "${tmpf}.dev" 2>/dev/null)
"$JQ" -n --argjson entries "${entries_json:-[]}" --argjson breakdown "${dev_json:-[]}" \
    --arg jf "${jfrom:-}" --arg jt "${jto:-}" \
    '{entries: $entries, breakdown: $breakdown, jalali_from: $jf, jalali_to: $jt}'
rm -f "$tmpf" "${tmpf}.agg" "${tmpf}.dev"
