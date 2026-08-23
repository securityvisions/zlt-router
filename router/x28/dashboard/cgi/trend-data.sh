#!/bin/sh
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo ""

TELEM="/data/proxy/usage/telemetry.log"
[ -f "$TELEM" ] || { echo '{"rsrp":[],"error":"no telemetry log"}'; exit 0; }

JQ=/data/proxy/jq

# Extract RSRP values from thermal-format rows (most frequent):
# Format: YYYY-MM-DD HH:MM:SS|temp=NN|load=N.NN|rsrp=-NN
tail -4320 "$TELEM" | grep 'rsrp=' | tail -72 | while IFS='|' read -r ts temp load rsrp; do
    t=$(echo "$ts" | awk '{print $2}' | cut -d: -f1,2)
    r=$(echo "$rsrp" | sed 's/^rsrp=//' | grep -oP -- '-?\d+' 2>/dev/null || \
        echo "$rsrp" | sed "s/rsrp=//" | tr -d ' ')
    [ -n "$r" ] && printf '{"t":"%s","v":%s}\n' "$t" "$r"
done | "$JQ" -s '{rsrp:.}' 2>/dev/null

# Extract daily GB totals from owners-d files (last 30 days)
echo '{"usage":['
first=1
for f in $(ls -1 /data/proxy/usage/owners-d/20* 2>/dev/null | tail -30); do
    d=$(basename "$f")
    mm_dd="${d:5:5}"
    total=$(awk -F'|' '{s+=$3+$4} END{printf "%.1f",s/1073741824}' "$f" 2>/dev/null)
    [ "$total" = "0.0" ] && continue
    [ "$first" = "0" ] && echo ","
    printf '{"date":"%s","gb":%s}' "$mm_dd" "$total"
    first=0
done
echo ']}'
