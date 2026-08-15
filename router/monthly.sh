#!/bin/sh
# Send previous month's bill (runs 1st of month)
. /etc/billing.conf 2>/dev/null
y=$(date +%Y)
m=$(date +%m | sed 's/^0//')
m=$((m - 1))
if [ "$m" -lt 1 ]; then
    m=12
    y=$((y - 1))
fi
pm=$(printf "%04d-%02d" "$y" "$m")
/root/tg.sh "$(/root/billing.sh --month "${LAST_FRIDAY:-no}" "$pm")"
