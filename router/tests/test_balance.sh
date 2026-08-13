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
cat > "$TMP/packages.json" <<EOF
{"data_plan":{"provider":"Samantel","subscriber":"989121234567","quota_gb":200,"remain_gb":146.5,"consumed_gb":53.5,"activation":"2026-07-01","expiry":"2027-08-05","status":"active","freshness":{"as_of_unix":1789000000,"source":"samantel_remain"}},"packages":[{"id":"samantel:4815","provider":"Samantel","subscriber":"989121234567","type":"Bonus","name":"Benefit Data - Summer Bonus","category":"data","window":"monthly","quota_gb":50,"remain_gb":16.5,"consumed_gb":33.5,"activation":"2026-07-01","expiry":"2026-09-01","status":"active","priority":2,"freshness":{"as_of_unix":1789000000,"source":"samantel_remain"}},{"id":"samantel:9921","provider":"Samantel","subscriber":"989121234567","type":"Base","name":"Benefit Data 150 GB","category":"data","window":null,"quota_gb":150,"remain_gb":130,"consumed_gb":20,"activation":"2026-08-05","expiry":"2027-08-05","status":"active","priority":1,"freshness":{"as_of_unix":1789000000,"source":"samantel_remain"}}]}
EOF
export RA_PACKAGES_JSON="$TMP/packages.json"

out=$(ra_json_balance)
assert_json_eq "balance full" '{"cached":true,"as_of_unix":1789000000,"data_plan":{"provider":"Samantel","subscriber":"989121234567","quota_gb":200,"remain_gb":146.5,"consumed_gb":53.5,"activation":"2026-07-01","expiry":"2027-08-05","status":"active","freshness":{"as_of_unix":1789000000,"source":"samantel_remain"}},"packages":[{"id":"samantel:4815","provider":"Samantel","subscriber":"989121234567","type":"Bonus","name":"Benefit Data - Summer Bonus","category":"data","window":"monthly","quota_gb":50,"remain_gb":16.5,"consumed_gb":33.5,"activation":"2026-07-01","expiry":"2026-09-01","status":"active","priority":2,"freshness":{"as_of_unix":1789000000,"source":"samantel_remain"}},{"id":"samantel:9921","provider":"Samantel","subscriber":"989121234567","type":"Base","name":"Benefit Data 150 GB","category":"data","window":null,"quota_gb":150,"remain_gb":130,"consumed_gb":20,"activation":"2026-08-05","expiry":"2027-08-05","status":"active","priority":1,"freshness":{"as_of_unix":1789000000,"source":"samantel_remain"}}],"total_gb":146.5,"plans":1,"main":{"quota":150,"remain":146.5,"pct":97,"expires":"2027-08-05","days":363},"expired":1,"drain":"~3.5 GB/day → ~41d left","series":[{"date":"2026-08-10","gb":146.5},{"date":"2026-08-09","gb":148.0}]}' "$out"

# No cache yet -> cached:false while retaining the new shape.
export RA_BALANCE_REPORT="$TMP/nonexistent"
export RA_BALANCE_REPORT_TS="$TMP/nonexistent.ts"
out=$(ra_json_balance)
assert_json_eq "balance no cache" '{"cached":false,"as_of_unix":0,"data_plan":null,"packages":[]}' "$out"

summary
