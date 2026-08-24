#!/bin/sh
# Fixture tests: ledger-range.cgi — multi-day walk, live-today, Jalali fields.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
CGI="$HERE/../x28/dashboard/cgi/ledger-range.sh"

PASS=0; FAIL=0
assert_contains() { if printf '%s' "$3" | grep -qF "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (missing: $2)"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

command -v jq >/dev/null 2>&1 || { echo "jq not available; skipping"; summary; exit 0; }

mkdir -p "$TMP/owners-d" "$TMP/day"
printf 'RATE_FULL=7700\nRATE_FRIDAY=4620\n' > "$TMP/billing.conf"
printf 'AA:BB:CC:DD:EE:77|Ali\n' > "$TMP/owners.conf"
# two rolled days with KNOWN totals: Ali 1G on each = 2G total, 15400T
printf 'Ali|aa:bb:cc:dd:ee:77|536870912|0\n' > "$TMP/owners-d/2026-08-21"
printf 'Ali|aa:bb:cc:dd:ee:77|536870912|0\n' > "$TMP/owners-d/2026-08-22"
# today live: another 1G
printf 'aa:bb:cc:dd:ee:77|192.168.70.20|laptop|1073741824|0\n' > "$TMP/day/2026-08-23"

run_cgi() { QUERY_STRING="$1" USAGE_DIR="$TMP" HN_LIB="$HERE/../hnlib.sh" \
    HN_OWNERS_FILE="$TMP/owners.conf" PEOPLE_TODAY="${2:-2026-08-23}" \
    JQ_BIN="$(command -v jq)" sh "$CGI" | tail -n +4; }

# ── multi-day walk: 3 days (2 rolled + 1 live) must ALL count ───────────────
# 0.5G(Fri 4620) + 0.5G(7700) + 1G live(7700) = 2G, 2310+3850+7700 = 13860T
out=$(run_cgi "from=2026-08-21&to=2026-08-23")
assert_contains "3-day walk sums all bytes (2G)" '"bytes": 2147483648' "$out"
assert_contains "3-day walk friday-discounted cost (13860T)" '"cost": 13860' "$out"

# ── single rolled day ────────────────────────────────────────────────────────
out=$(run_cgi "from=2026-08-21&to=2026-08-21")
assert_contains "single day bytes" '"bytes": 536870912' "$out"
assert_contains "single friday day discounted cost" '"cost": 2310' "$out"

# ── jalali fields present ────────────────────────────────────────────────────
assert_contains "jalali_from present" '"jalali_from": "1405-05-30"' "$out"
assert_contains "jalali_to present" '"jalali_to": "1405-05-30"' "$out"

# ── empty range → empty entries, no error ────────────────────────────────────
out=$(run_cgi "from=2026-01-01&to=2026-01-02")
assert_contains "empty range entries" '"entries": []' "$out"

# ── CSV export: text/csv, per-person rows ───────────────────────────────────
out=$(QUERY_STRING="from=2026-08-21&to=2026-08-23&format=csv" USAGE_DIR="$TMP" HN_LIB="$HERE/../hnlib.sh" \
    HN_OWNERS_FILE="$TMP/owners.conf" PEOPLE_TODAY="2026-08-23" \
    JQ_BIN="$(command -v jq)" sh "$CGI")
assert_contains "csv content type" "Content-Type: text/csv" "$out"
assert_contains "csv attachment disposition" "attachment; filename=\"ledger-2026-08-21_2026-08-23.csv\"" "$out"
assert_contains "csv header row" "person,gb,cost_toman" "$out"
assert_contains "csv Ali row" "Ali,2.00,13860" "$out"

# ── missing params → error ───────────────────────────────────────────────────
out=$(QUERY_STRING="" sh "$CGI" | tail -n +4)
assert_contains "missing from rejected" 'missing from date' "$out"

summary
