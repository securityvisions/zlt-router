#!/bin/sh
# Unit tests: /balance — parse the cached report text + balance history series.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
. "$HERE/lib.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/balance-log"
cat > "$TMP/balance_report" <<EOF
📦 Samantel — 146.5 GB left across 1 plan(s)
Main: 150 GB · 146.5 GB left (97%) · expires 2027-08-05 (~363d)
+1 expired plan(s)

Drain ~3.5 GB/day → ~41d left (est. — ISP updates slowly)
EOF
echo "1789000000" > "$TMP/balance_report.ts"
cat > "$TMP/balance-log/2026-08.log" <<EOF
2026-08-09|148.0
2026-08-10|146.5
EOF
export RA_BALANCE_REPORT="$TMP/balance_report"
export RA_BALANCE_REPORT_TS="$TMP/balance_report.ts"
export RA_BALANCE_LOG_DIR="$TMP/balance-log"

out=$(ra_json_balance)
assert_json_eq "balance full" '{"cached":true,"as_of_unix":1789000000,"total_gb":146.5,"plans":1,"main":{"quota":150,"remain":146.5,"pct":97,"expires":"2027-08-05","days":363},"expired":1,"drain":"~3.5 GB/day → ~41d left","series":[{"date":"2026-08-10","gb":146.5},{"date":"2026-08-09","gb":148.0}]}' "$out"

# No cache yet -> cached:false, minimal shape
export RA_BALANCE_REPORT="$TMP/nonexistent"
export RA_BALANCE_REPORT_TS="$TMP/nonexistent.ts"
out=$(ra_json_balance)
assert_json_eq "balance no cache" '{"cached":false,"as_of_unix":0}' "$out"

summary
