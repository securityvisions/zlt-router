#!/bin/sh
# Unit tests: Outage Ledger — pairing, totals per Jalali month, idempotency.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
HN_LIB="$HERE/../hnlib.sh"
[ -f "$HN_LIB" ] || HN_LIB="$HERE/hnlib.sh"
. "$HN_LIB"
LEDGER_SH="$HERE/../x28/x28-outage-ledger.sh"

PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n' "$2"; printf '  actual: [%s]\n' "$3"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# ── hn_outage_pair ──────────────────────────────────────────────────────────
LEDGER="$TMP/ledger.log"
# Single pair
printf '1000|down\n2000|up\n' > "$LEDGER"
assert_eq "pair single" "1000|2000|1000" "$(hn_outage_pair "$LEDGER")"
# Consecutive downs: second overwrites first
printf '1000|down\n1500|down\n2000|up\n' > "$LEDGER"
assert_eq "pair consecutive downs" "1500|2000|500" "$(hn_outage_pair "$LEDGER")"
# Multiple pairs
printf '1000|down\n1500|up\n2000|down\n3000|up\n' > "$LEDGER"
out=$(hn_outage_pair "$LEDGER")
assert_eq "pair multiple count" "2" "$(echo "$out" | wc -l | tr -d ' ')"
assert_eq "pair first" "1000|1500|500" "$(echo "$out" | head -n1)"
assert_eq "pair second" "2000|3000|1000" "$(echo "$out" | tail -n1)"
# Open down (no up) => no pair
printf '1000|down\n' > "$LEDGER"
assert_eq "pair open none" "" "$(hn_outage_pair "$LEDGER")"
# Unsorted input should be sorted
printf '2000|up\n1000|down\n' > "$LEDGER"
assert_eq "pair unsorted" "1000|2000|1000" "$(hn_outage_pair "$LEDGER")"

# ── hn_outage_format_duration ───────────────────────────────────────────────
assert_eq "fmt 0" "0m" "$(hn_outage_format_duration 0)"
assert_eq "fmt 60" "1m" "$(hn_outage_format_duration 60)"
assert_eq "fmt 3600" "1h" "$(hn_outage_format_duration 3600)"
assert_eq "fmt 5400" "1h30m" "$(hn_outage_format_duration 5400)"
assert_eq "fmt 8400" "2h20m" "$(hn_outage_format_duration 8400)"

# ── hn_outage_total per Jalali month ───────────────────────────────────────
# Use known Jalali month 1405-06 => greg 2026-08-23 to 2026-09-22
# Create ledger with intervals:
#   2026-08-20 (before month) to 2026-08-25 (inside) => overlap 2 days (23,24)
#   2026-09-10 to 2026-09-12 => full inside => 2 days
#   2026-09-22 10:00 to 2026-09-23 10:00 => overlap only 14 hours of 22nd
# Use epoch via date -d (GNU)
start_e=$(date -d "2026-08-23" +%s)
end_e=$(date -d "2026-09-22" +%s); end_next=$((end_e + 86400))
# Interval1: 2026-08-20 to 2026-08-25 => 5 days, but overlap with month is 2026-08-23 to 2026-08-25 => 2 days
int1_down=$(date -d "2026-08-20" +%s); int1_up=$(date -d "2026-08-25" +%s)
# Interval2: inside
int2_down=$(date -d "2026-09-10" +%s); int2_up=$(date -d "2026-09-12" +%s)
# Interval3: partial at end
int3_down=$(date -d "2026-09-22 10:00" +%s); int3_up=$(date -d "2026-09-23 10:00" +%s)

printf '%s|down\n%s|up\n%s|down\n%s|up\n%s|down\n%s|up\n' \
  "$int1_down" "$int1_up" "$int2_down" "$int2_up" "$int3_down" "$int3_up" > "$LEDGER"

total=$(hn_outage_total "$LEDGER" "1405-06")
# Expected: 2d (172800) + 2d (172800) + 14h (50400) = 396000
expected=$(( 2*86400 + 2*86400 + 14*3600 ))
assert_eq "total 1405-06 overlap" "$expected" "$total"

# Open down: last entry down at 2026-09-20, now 2026-09-22 12:00, month 1405-06 => overlap 2 days 12h
HN_OUTAGE_NOW=$(date -d "2026-09-22 12:00" +%s)
export HN_OUTAGE_NOW
# ledger: down at 2026-09-20, no up
printf '%s|down\n' "$(date -d "2026-09-20" +%s)" > "$LEDGER"
total=$(hn_outage_total "$LEDGER" "1405-06")
# Overlap from 2026-09-20 to 2026-09-22 12:00 => 2.5 days = 216000
expected2=$(( 2*86400 + 12*3600 ))
assert_eq "total open down" "$expected2" "$total"
unset HN_OUTAGE_NOW

# Missing ledger -> 0
assert_eq "total missing ledger" "0" "$(hn_outage_total "$TMP/nonexistent" "1405-06")"
# Invalid month -> 0
printf '1000|down\n2000|up\n' > "$LEDGER"
assert_eq "total invalid month" "0" "$(hn_outage_total "$LEDGER" "invalid")"

# ── x28-outage-ledger.sh idempotency ─────────────────────────────────────────
LEDGER2="$TMP/ledger2.log"
export HN_OUTAGE_LEDGER="$LEDGER2"
export HN_OUTAGE_NOW="1000"
sh "$LEDGER_SH" add-down 2>/dev/null
sh "$LEDGER_SH" add-down 2>/dev/null
lines=$(wc -l < "$LEDGER2" | tr -d ' ')
assert_eq "add-down idempotent" "1" "$lines"
export HN_OUTAGE_NOW="2000"
sh "$LEDGER_SH" add-up 2>/dev/null
sh "$LEDGER_SH" add-up 2>/dev/null
lines=$(wc -l < "$LEDGER2" | tr -d ' ')
assert_eq "add-up idempotent" "2" "$lines"
# add-down after up should add
export HN_OUTAGE_NOW="3000"
sh "$LEDGER_SH" add-down 2>/dev/null
lines=$(wc -l < "$LEDGER2" | tr -d ' ')
assert_eq "add-down after up" "3" "$lines"

# ── report card ──────────────────────────────────────────────────────────────
# With ledger containing one completed pair
LEDGER3="$TMP/ledger3.log"
export HN_OUTAGE_LEDGER="$LEDGER3"
printf '1000|down\n2000|up\n' > "$LEDGER3"
export HN_OUTAGE_NOW="3000"
card=$(HN_OUTAGE_LEDGER="$LEDGER3" HN_OUTAGE_NOW="3000" sh "$LEDGER_SH" report "1405-06" 2>/dev/null)
echo "$card" | grep -q "Outages" || { echo "FAIL - report header"; FAIL=$((FAIL+1)); }
echo "$card" | grep -q "1405-06" || { echo "FAIL - report month"; FAIL=$((FAIL+1)); }
PASS=$((PASS+2))

unset HN_OUTAGE_LEDGER
unset HN_OUTAGE_NOW

summary
