#!/bin/sh
# Unit tests: /clients — DHCP leases joined with names + today's usage.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
. "$HERE/lib.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/leases" <<EOF
1690 aa:bb:cc:dd:ee:ff 192.168.1.5 iPhone *
1690 96:04:e1:00:00:00 192.168.1.6 laptop *
1690 00:11:22:33:44:55 192.168.1.7 * *
EOF
echo "aa:bb:cc:dd:ee:ff iPhone" > "$TMP/names"
export RA_DHCP_LEASES="$TMP/leases"
export RA_USER_NAMES="$TMP/names"

ra_usage_today() { echo "iPhone|aa:bb:cc:dd:ee:ff|1073741824"; }

out=$(ra_json_clients)
assert_json_eq "clients join names + usage, unknown fallback" '{"clients":[{"mac":"aa:bb:cc:dd:ee:ff","ip":"192.168.1.5","name":"iPhone","hostname":"iPhone","today_gb":1.0},{"mac":"96:04:e1:00:00:00","ip":"192.168.1.6","name":"laptop","hostname":"laptop","today_gb":0.0},{"mac":"00:11:22:33:44:55","ip":"192.168.1.7","name":"Unknown-00:11:22","hostname":"","today_gb":0.0}]}' "$out"

summary
