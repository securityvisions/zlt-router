#!/bin/sh
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo ""

LEDGER="/data/proxy/outage-ledger.log"
[ -f "$LEDGER" ] || { echo '{"incidents":[],"total_s":0}'; exit 0; }

JQ=/data/proxy/jq

# Pair consecutive down/up entries into incidents
"$JQ" -R -s '
    split("\n") | map(select(length > 0)) |
    map(split("|")) |
    map({epoch: (.[0] | tonumber? // 0), kind: .[1]}) |
    # pair into incidents
    reduce .[] as $e (
        {incidents: [], current: null};
        if $e.kind == "down" then
            .current = {start: $e.epoch}
        elif $e.kind == "up" and .current != null then
            .incidents += [{start: .current.start, end: $e.epoch, duration_s: ($e.epoch - .current.start)}]
            | .current = null
        else . end
    ) | {incidents: .incidents, total_s: ([.incidents[].duration_s] | add // 0)}
' "$LEDGER" 2>/dev/null
