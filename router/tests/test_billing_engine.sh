#!/bin/sh
# Unit tests: router/billing.sh — deep billing and serialization engine
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
. "$HERE/lib.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/billing.conf" <<EOF
RATE_FULL_TOMAN=7700
RATE_FRIDAY_TOMAN=4620
ROUND=1000
EOF

export BILLING_CONF="$TMP/billing.conf"

. "$HERE/../billing.sh"

# Test 1: Rate resolution
assert_eq "rate full" "7700" "$(billing_rate_for no)"
assert_eq "rate friday" "4620" "$(billing_rate_for yes)"

# Test 2: In-memory stream calculation to JSON
MOCK_STREAM=$(printf "iPhone|aa:bb:cc:dd:ee:ff|1073741824\nlaptop|96:04:e1:00:00:00|268435456\n")

json_full=$(echo "$MOCK_STREAM" | billing_stream_to_json no 7700 4620 1000)
assert_json_eq "stream to json (full rate)" '{"friday":false,"rate_full":7700,"rate_friday":4620,"rows":[{"name":"iPhone","mac":"aa:bb:cc:dd:ee:ff","gb":1.0,"toman":8000,"share":80.0},{"name":"laptop","mac":"96:04:e1:00:00:00","gb":0.25,"toman":2000,"share":20.0}],"total_gb":1.25,"total_toman":10000}' "$json_full"

json_friday=$(echo "$MOCK_STREAM" | billing_stream_to_json yes 7700 4620 1000)
assert_json_eq "stream to json (friday rate)" '{"friday":true,"rate_full":7700,"rate_friday":4620,"rows":[{"name":"iPhone","mac":"aa:bb:cc:dd:ee:ff","gb":1.0,"toman":5000,"share":80.0},{"name":"laptop","mac":"96:04:e1:00:00:00","gb":0.25,"toman":1000,"share":20.0}],"total_gb":1.25,"total_toman":6000}' "$json_friday"

# Test 3: In-memory stream calculation to aligned text
text_out=$(echo "$MOCK_STREAM" | billing_stream_to_text no 7700 1000 "Today's usage")
if echo "$text_out" | grep -q "iPhone" && echo "$text_out" | grep -q "TOTAL"; then
    PASS=$((PASS+1))
else
    FAIL=$((FAIL+1))
    echo "FAIL - stream to text contains table headers and totals"
fi

summary
