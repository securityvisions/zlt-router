#!/bin/sh
# ledger-range.cgi — aggregate owners-d between two Gregorian dates.
# GET params: ?from=YYYY-MM-DD&to=YYYY-MM-DD
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo ""

HN_LIB="/data/proxy/hnlib.sh"
[ -f "$HN_LIB" ] || HN_LIB="/root/hnlib.sh"
[ -f "$HN_LIB" ] && . "$HN_LIB" 2>/dev/null || true

from=$(echo "${QUERY_STRING:-}" | sed -n "s/.*from=\([^&]*\).*/\1/p")
to=$(echo "${QUERY_STRING:-}" | sed -n "s/.*to=\([^&]*\).*/\1/p")
JQ=/data/proxy/jq

case "$from" in ??????????*) ;; *) echo '{"error":"missing from date"}'; exit 0 ;; esac
case "$to" in ??????????*) ;; *) echo '{"error":"missing to date"}'; exit 0 ;; esac

OD=/data/proxy/usage/owners-d
[ -d "$OD" ] || { echo '{"error":"no owner data"}'; exit 0; }

tmpf=$(mktemp)
cur="$from"
while [ -n "$cur" ]; do
    [ "$cur" \> "$to" ] 2>/dev/null && break
    f="$OD/$cur"
    if [ -f "$f" ]; then
        is_fri=1; nd=$(echo "$cur" | awk -F- '{print $3}'); [ "$nd" = "05" ] || [ "$nd" = "12" ] && is_fri=0
        # check if Friday via day-of-week
        dow=$("$HN_LIB" hn_http_date_epoch "Thu, $cur 00:00:00 GMT" 2>/dev/null)
        if [ -n "$dow" ]; then
            u=$(( ((dow % 7) + 3) % 7 + 1 ))
            [ "$u" = "5" ] && is_fri=1 || is_fri=0
        fi
        rate=7700; [ "$is_fri" = "1" ] && rate=4620
        while IFS='|' read -r person mac up down; do
            [ -n "$person" ] || continue
            bytes=$(( ${up:-0} + ${down:-0} ))
            cost=$(awk -v b="$bytes" -v r="$rate" 'BEGIN{printf "%.0f", b/1073741824*r}')
            printf '%s\t%s\t%s\t%s\n' "$person" "$mac" "$bytes" "$cost" >> "$tmpf"
        done < "$f"
    fi
    nxt=$("$HN_LIB" hn_jalali_to_greg "$(printf '%s' "$cur" | "$JQ" -rR '"x"' >/dev/null; echo "")" 2>/dev/null || true)
    # use awk to advance one day (busybox-safe)
    nxt=$(date -d "$cur +1 day" +%F 2>/dev/null)
    if [ -z "$nxt" ]; then
        nxt=$(echo "$cur" | awk -F- -v OFS=- '{$3=sprintf("%02d",$3+1);
            dim[2]=28;dim[4]=30;dim[6]=30;dim[9]=30;dim[11]=30;
            if($1%4==0&&($1%100!=0||$1%400==0))dim[2]=29;
            if($3>dim[$2]){$3=1;$2++};if($2>12){$2=1;$1++}}1')
    fi
    cur="$nxt"
done

if [ ! -s "$tmpf" ]; then rm -f "$tmpf"; echo '[]'; exit 0; fi

# aggregate per person
sort "$tmpf" | awk -F'\t' '{u[$1]+=$3;c[$1]+=$4}
    END{for(p in u) printf "{\"person\":\"%s\",\"bytes\":%d,\"cost\":%d}\n",p,u[p],c[p]}' "$tmpf" > "${tmpf}.agg"

# per-device breakdown
sort "$tmpf" | awk -F'\t' '{u[$1 "\t" $2]+=$3}
    END{for(k in u){split(k,a,"\t"); printf "{\"person\":\"%s\",\"mac\":\"%s\",\"bytes\":%d}\n",a[1],a[2],u[k]}}' "$tmpf" > "${tmpf}.dev"

# combine into single JSON
entries_json=$("$JQ" -sc '.' "${tmpf}.agg" 2>/dev/null)
dev_json=$("$JQ" -sc '.' "${tmpf}.dev" 2>/dev/null)
"$JQ" -n --argjson entries "${entries_json:-[]}" --argjson breakdown "${dev_json:-[]}" \
    '{entries: $entries, breakdown: $breakdown}'
rm -f "$tmpf" "${tmpf}.agg" "${tmpf}.dev"
