#!/bin/sh
# Unit tests: /cost — the Toman cost model (rate × GB, round to 1,000, share %).
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
. "$HERE/lib.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/billing.conf" <<EOF
RATE_FULL_TOMAN=7700
RATE_FRIDAY_TOMAN=4620
ROUND=1000
EOF
export RA_BILLING_CONF="$TMP/billing.conf"

ra_usage_today() {
    echo "iPhone|aa:bb:cc:dd:ee:ff|1073741824"
    echo "laptop|96:04:e1:00:00:00|268435456"
}

out=$(ra_json_cost no)
assert_json_eq "cost full rate: hand-computed" '{"friday":false,"rate_full":7700,"rate_friday":4620,"rows":[{"name":"iPhone","mac":"aa:bb:cc:dd:ee:ff","gb":1.0,"toman":8000,"share":80.0},{"name":"laptop","mac":"96:04:e1:00:00:00","gb":0.25,"toman":2000,"share":20.0}],"total_gb":1.25,"total_toman":10000}' "$out"

out=$(ra_json_cost yes)
assert_json_eq "cost friday rate: hand-computed" '{"friday":true,"rate_full":7700,"rate_friday":4620,"rows":[{"name":"iPhone","mac":"aa:bb:cc:dd:ee:ff","gb":1.0,"toman":5000,"share":80.0},{"name":"laptop","mac":"96:04:e1:00:00:00","gb":0.25,"toman":1000,"share":20.0}],"total_gb":1.25,"total_toman":6000}' "$out"

# rounding at the 1000 boundary: 0.5 GB at full rate = 3850 -> 4000
ra_usage_today() { echo "d|00:11:22:33:44:55|536870912"; }
out=$(ra_json_cost no)
assert_json_eq "cost rounds half up to nearest 1000" '{"friday":false,"rate_full":7700,"rate_friday":4620,"rows":[{"name":"d","mac":"00:11:22:33:44:55","gb":0.5,"toman":4000,"share":100.0}],"total_gb":0.5,"total_toman":4000}' "$out"

summary
