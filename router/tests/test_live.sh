#!/bin/sh
# Unit tests: /live — cumulative per-MAC + WAN byte counters (app diffs for rate).
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
. "$HERE/lib.sh"

ra_nlbw_macs() {
    echo "aa:bb:cc:dd:ee:ff|1000|500"
    echo "96:04:e1:00:00:00|2000|1000"
    echo "ff:ff:ff:ff:ff:ff|99999|99999"   # router/broadcast — excluded
}
ra_wan_bytes() { echo "15000|9000"; }
ra_ts() { echo "1789000000"; }

out=$(ra_json_live)
assert_json_eq "live excludes router macs" '{"ts":1789000000,"wan":{"rx_bytes":15000,"tx_bytes":9000},"devices":[{"mac":"aa:bb:cc:dd:ee:ff","rx_bytes":1000,"tx_bytes":500},{"mac":"96:04:e1:00:00:00","rx_bytes":2000,"tx_bytes":1000}]}' "$out"

summary
