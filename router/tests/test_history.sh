#!/bin/sh
# Unit tests: /history — hourly telemetry series (usage) and daily balance series.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
. "$HERE/lib.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/telemetry" "$TMP/balance-log"

# 26 hourly rows -> days=1 keeps the last 24
i=1
while [ "$i" -le 26 ]; do
    d=$((i % 28 + 1)); h=$((i % 24))
    printf '2026-08-%02d %02d:00|%d.0|146.5|up\n' "$d" "$h" "$i"
    i=$((i + 1))
done > "$TMP/telemetry/hourly.log"

cat > "$TMP/balance-log/2026-08.log" <<EOF
2026-08-09|148.0
2026-08-10|146.5
EOF
export RA_TELEMETRY_LOG="$TMP/telemetry/hourly.log"
export RA_BALANCE_LOG_DIR="$TMP/balance-log"

out=$(ra_json_history usage 1)
assert_eq "usage history days=1 keeps 24 points" "24" "$(echo "$out" | jq '.points | length')"
assert_eq "usage history oldest kept" "3" "$(echo "$out" | jq '.points[0].value + 0')"
assert_eq "usage history newest" "26" "$(echo "$out" | jq '.points[-1].value + 0')"
assert_eq "usage history kind" "usage" "$(echo "$out" | jq -r '.kind')"

out=$(ra_json_history balance 30)
assert_json_eq "balance history daily series oldest-first" '{"kind":"balance","points":[{"ts":"2026-08-09","value":148.0},{"ts":"2026-08-10","value":146.5}]}' "$out"

out=$(ra_json_history balance 1)
assert_eq "balance days=1 keeps 1 point" "1" "$(echo "$out" | jq '.points | length')"

summary
