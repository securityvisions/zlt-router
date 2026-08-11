#!/bin/sh
# Unit tests: /usage — today (from usage.sh --today pipe lines) and month (log file).
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
. "$HERE/lib.sh"

# --- today ---
ra_usage_today() {
    echo "laptop|96:04:e1:00:00:00|536870912"
    echo "iPhone|aa:bb:cc:dd:ee:ff|1073741824"
    echo "smarttv|ff:ff:ff:ff:ff:ff|999999999"
}
out=$(ra_json_usage today)
assert_json_eq "usage today sorted desc, router mac excluded" '{"period":"today","rows":[{"name":"iPhone","mac":"aa:bb:cc:dd:ee:ff","gb":1.0},{"name":"laptop","mac":"96:04:e1:00:00:00","gb":0.5}]}' "$out"

# --- month (tolerant parse of the monthly log: DATE|KEY|BYTES and KEY|BYTES) ---
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/usage-log"
cat > "$TMP/usage-log/2026-08.log" <<EOF
2026-08-01|aa:bb:cc:dd:ee:ff|1073741824
2026-08-01|96:04:e1:00:00:00|536870912
2026-08-02|aa:bb:cc:dd:ee:ff|1073741824
96:04:e1:00:00:00|1073741824
EOF
export RA_USAGE_LOG_DIR="$TMP/usage-log"
export RA_USER_NAMES="$TMP/user-names"
echo "aa:bb:cc:dd:ee:ff iPhone" > "$TMP/user-names"
echo "96:04:e1:00:00:00 laptop" >> "$TMP/user-names"

out=$(ra_json_usage month)
assert_json_eq "usage month resolves names + sums days" '{"period":"month","rows":[{"name":"iPhone","mac":"aa:bb:cc:dd:ee:ff","gb":2.0},{"name":"laptop","mac":"96:04:e1:00:00:00","gb":1.5}]}' "$out"

summary
