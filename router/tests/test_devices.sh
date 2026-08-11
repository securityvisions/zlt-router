#!/bin/sh
# Unit tests: /devices — known devices: custom names + watchlist, joined with usage.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
. "$HERE/lib.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/leases" <<EOF
1690 96:04:e1:00:00:00 192.168.1.6 laptop *
EOF
echo "aa:bb:cc:dd:ee:ff iPhone" > "$TMP/names"
echo "aa:bb:cc:dd:ee:ff" > "$TMP/watchlist"
echo "96:04:e1:00:00:00" >> "$TMP/watchlist"
export RA_DHCP_LEASES="$TMP/leases"
export RA_USER_NAMES="$TMP/names"
export RA_WATCHLIST="$TMP/watchlist"

ra_usage_today() { echo "iPhone|aa:bb:cc:dd:ee:ff|1073741824"; }

out=$(ra_json_devices)
assert_json_eq "devices = names + watchlist, sources labeled" '{"devices":[{"mac":"aa:bb:cc:dd:ee:ff","name":"iPhone","source":"user-names","watched":true,"today_gb":1.0},{"mac":"96:04:e1:00:00:00","name":"laptop","source":"lease","watched":true,"today_gb":0.0}]}' "$out"

summary
