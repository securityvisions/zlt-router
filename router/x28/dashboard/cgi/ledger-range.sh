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
    nxt=$(echo "$cur" | awk '{y=substr($0,1,4)+0;m=substr($0,6,2)+0;d=substr($0,9,2)+0;
        d++; dim[2]=(y%4==0&&(y%100!=0||y%400==0))?29:28; dim[4]=dim[6]=dim[9]=dim[11]=30;
        if(d>dim[m]){d=1;m++};if(m>12){m=1;y++}
        printf "%04d-%02d-%02d",y,m,d}')
    cur="$nxt"
done

if [ ! -s "$tmpf" ]; then rm -f "$tmpf"; echo '[]'; exit 0; fi

# aggregate per person
sort "$tmpf" | awk -F'\t' '{u[$1]+=$3;c[$1]+=$4}
    END{for(p in u) printf "{\"person\":\"%s\",\"bytes\":%d,\"cost\":%d}\n",p,u[p],c[p]}' "$tmpf" | \
"$JQ" -s '{entries:.}'
rm -f "$tmpf"
