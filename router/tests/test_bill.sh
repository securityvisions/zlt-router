#!/bin/sh
# Unit tests: /bill — monthly cost from the monthly log (same cost model as /cost).
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
. "$HERE/lib.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/usage-log"
cat > "$TMP/usage-log/2026-08.log" <<EOF
2026-08-01|aa:bb:cc:dd:ee:ff|1073741824
2026-08-01|96:04:e1:00:00:00|536870912
2026-08-02|aa:bb:cc:dd:ee:ff|1073741824
EOF
cat > "$TMP/billing.conf" <<EOF
RATE_FULL_TOMAN=7700
RATE_FRIDAY_TOMAN=4620
EOF
echo "aa:bb:cc:dd:ee:ff iPhone" > "$TMP/user-names"
echo "96:04:e1:00:00:00 laptop" >> "$TMP/user-names"
export RA_USAGE_LOG_DIR="$TMP/usage-log"
export RA_USER_NAMES="$TMP/user-names"
export RA_BILLING_CONF="$TMP/billing.conf"

out=$(ra_json_bill no 2026-08)
assert_json_eq "bill full: 2GB iPhone -> 15000, 0.5GB laptop -> 4000" '{"period":"2026-08","friday":false,"rate_full":7700,"rate_friday":4620,"rows":[{"name":"iPhone","mac":"aa:bb:cc:dd:ee:ff","gb":2.0,"toman":15000,"share":80.0},{"name":"laptop","mac":"96:04:e1:00:00:00","gb":0.5,"toman":4000,"share":20.0}],"total_gb":2.5,"total_toman":19000}' "$out"

out=$(ra_json_bill yes 2026-08)
assert_json_eq "bill friday: 2GB -> 9000, 0.5GB -> 2000" '{"period":"2026-08","friday":true,"rate_full":7700,"rate_friday":4620,"rows":[{"name":"iPhone","mac":"aa:bb:cc:dd:ee:ff","gb":2.0,"toman":9000,"share":80.0},{"name":"laptop","mac":"96:04:e1:00:00:00","gb":0.5,"toman":2000,"share":20.0}],"total_gb":2.5,"total_toman":11000}' "$out"

# ROUND from billing.conf must flow through to /bill: iPhone 2GB=15400 → 16000 at ROUND=2000
printf 'RATE_FULL_TOMAN=7700\nRATE_FRIDAY_TOMAN=4620\nROUND=2000\n' > "$TMP/billing.conf"
out=$(ra_json_bill no 2026-08)
assert_json_eq "bill honors ROUND=2000" '{"period":"2026-08","friday":false,"rate_full":7700,"rate_friday":4620,"rows":[{"name":"iPhone","mac":"aa:bb:cc:dd:ee:ff","gb":2.0,"toman":16000,"share":80.0},{"name":"laptop","mac":"96:04:e1:00:00:00","gb":0.5,"toman":4000,"share":20.0}],"total_gb":2.5,"total_toman":20000}' "$out"

summary
