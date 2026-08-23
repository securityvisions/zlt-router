#!/bin/sh
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo ""

TELEM="/data/proxy/usage/telemetry.log"
JQ=/data/proxy/jq
[ -f "$TELEM" ] || { echo '{"rsrp":[],"usage":[]}'; exit 0; }

# --- RSRP from thermal rows (last 72h) ---
rsrp_json=$(tail -4320 "$TELEM" | grep 'rsrp=' | tail -72 | while IFS='|' read -r ts temp load rsrp; do
    t=$(echo "$ts" | awk '{print $2}' | cut -d: -f1,2)
    r=$(echo "$rsrp" | sed 's/^rsrp=//' | grep -oE -- '-?[0-9]+' 2>/dev/null || \
        echo "$rsrp" | sed "s/rsrp=//" | tr -d ' ')
    [ -n "$r" ] && printf '{"t":"%s","v":%s}\n' "$t" "$r"
done | "$JQ" -s '.' 2>/dev/null)

# --- Usage from owners-d files (last 30 days) ---
usage_first=1
usage_json=""
for f in $(ls -1 /data/proxy/usage/owners-d/20* 2>/dev/null | tail -30); do
    d=$(basename "$f")
    mm_dd="${d:5:5}"
    total=$(awk -F'|' '{s+=$3+$4} END{printf "%.1f",s/1073741824}' "$f" 2>/dev/null)
    [ "$total" = "0.0" ] && continue
    [ "$usage_first" = "0" ] && usage_json="$usage_json,"
    usage_json="$usage_json{\"date\":\"$mm_dd\",\"gb\":$total}"
    usage_first=0
done

# --- combined single JSON output ---
printf '{"rsrp":%s,"usage":[%s]}' "${rsrp_json:-[]}" "$usage_json"
