#!/bin/sh
# Fixture tests: ledger-year.cgi — per-Jalali-month per-person GB from rollups.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
CGI="$HERE/../x28/dashboard/cgi/ledger-year.sh"

PASS=0; FAIL=0
assert_contains() { if printf '%s' "$3" | grep -qF "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (missing: $2)"; fi; }
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (expect [$2] got [$3])"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

command -v jq >/dev/null 2>&1 || { echo "jq not available; skipping"; summary; exit 0; }

mkdir -p "$TMP/rollups"
printf '2026-08-21|parsa|2147483647|9971\n2026-08-21|baba|2164045|9\n2026-07-24|Ali|1073741824|4620\n' > "$TMP/rollups/1405-05.tsv"
printf '2026-08-23|Ali|1073741824|7700\n' > "$TMP/rollups/1405-06.tsv"

out=$(QUERY_STRING="year=1405" USAGE_DIR="$TMP" HN_LIB="$HERE/../hnlib.sh" \
    JQ_BIN="$(command -v jq)" sh "$CGI" | tail -n +4)

# all 12 Jalali months present (chart continuity)
n=$(printf '%s' "$out" | grep -o '"month"' | wc -l | tr -d ' ')
assert_eq "12 month entries" "12" "$n"

# month 1405-05: مرداد, total 2147483647+2164045+1073741824 = 3.00 GB, per-person
assert_contains "month 1405-05 present" '"month": "1405-05"' "$out"
assert_contains "persian label مرداد" '"label": "مرداد"' "$out"
assert_contains "1405-05 total 3.00 GB" '"total_gb": 3.00' "$out"
assert_contains "1405-05 Ali 1.00" '"Ali": 1.00' "$out"
assert_contains "1405-05 parsa 2.00" '"parsa": 2.00' "$out"

# month 1405-06: only Ali
assert_contains "1405-06 Ali 1.00" '"Ali": 1.00' "$out"

# year totals across months: Ali 2.00
assert_contains "year persons total Ali 2.00" '"Ali": 2.00' "$out"

# empty year: all zeros, no crash
mkdir -p "$TMP/empty"
out=$(QUERY_STRING="year=1370" USAGE_DIR="$TMP/empty" HN_LIB="$HERE/../hnlib.sh" \
    JQ_BIN="$(command -v jq)" sh "$CGI" | tail -n +4)
assert_contains "empty year still 12 months" '"month"' "$out"
assert_contains "empty year total zero" '"total_gb": 0.00' "$out"

# person names containing spaces survive the pipeline
printf '2026-08-21|Ali Reza|1073741824|7700\n' > "$TMP/rollups/1405-07.tsv"
out=$(QUERY_STRING="year=1405" USAGE_DIR="$TMP" HN_LIB="$HERE/../hnlib.sh" \
    JQ_BIN="$(command -v jq)" sh "$CGI" | tail -n +4)
assert_contains "person with space kept" '"Ali Reza": 1.00' "$out"

summary
