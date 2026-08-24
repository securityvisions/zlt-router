#!/bin/sh
# Unit tests: usage-collect roll — closes out the COMPLETED day:
# day/ file → owners-d (attributed) + monthly log + Jalali month rollup.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
HN_LIB="$HERE/../hnlib.sh"
UC="$HERE/../x28/usage-collect.sh"

PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n' "$2"; printf '  actual: [%s]\n' "$3"; fi; }
assert_contains() { if printf '%s' "$3" | grep -qF "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (missing: $2)"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/day" "$TMP/month"
printf 'RATE_FULL=7700\nRATE_FRIDAY=4620\n' > "$TMP/billing.conf"
printf 'AA:BB:CC:DD:EE:77|Ali\n' > "$TMP/owners.conf"
# completed day has traffic; the (simulated) new day file is empty
printf 'aa:bb:cc:dd:ee:77|192.168.70.20|laptop|1073741824|0\nde:ad:be:ef:00:99|192.168.70.30|phone|0|1073741824\n' > "$TMP/day/2026-08-22"
: > "$TMP/day/2026-08-23"

export USAGE_DIR="$TMP" HN_LIB="$HN_LIB" HN_OWNERS_FILE="$TMP/owners.conf"
export LEDGER_STORE="$HERE/../x28/ledger-store.sh"
# keep the clock-gated weekly digest block inert during tests
ROLL_DOW=1 ROLL_HOUR=12 sh "$UC" roll 2026-08-22

# ── owners-d: completed day attributed, new day untouched ───────────────────
out=$(cat "$TMP/owners-d/2026-08-22" 2>/dev/null)
assert_contains "owners-d closed day attributed" "Ali|aa:bb:cc:dd:ee:77|1073741824|0" "$out"
assert_contains "owners-d unassigned fallback" "unassigned|de:ad:be:ef:00:99|0|1073741824" "$out"
[ ! -f "$TMP/owners-d/2026-08-23" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - new day must not be rolled"; }

# ── monthly log: line keyed by the closed day, in that day's month ──────────
out=$(cat "$TMP/month/2026-08.log" 2>/dev/null)
assert_contains "month log keyed by closed day" "2026-08-22 total_up=1073741824 total_down=1073741824" "$out"

# ── marker: second roll for the same day is a no-op ─────────────────────────
printf 'tampered|0|0\n' > "$TMP/owners-d/2026-08-22"
ROLL_DOW=1 ROLL_HOUR=12 sh "$UC" roll 2026-08-22
out=$(cat "$TMP/owners-d/2026-08-22")
assert_eq "marker prevents re-roll" "tampered|0|0" "$out"

# ── rollup: Jalali month file regenerated for the closed day ────────────────
rm -f "$TMP/owners-d/2026-08-22"
printf 'aa:bb:cc:dd:ee:77|192.168.70.20|laptop|1073741824|0\n' > "$TMP/day/2026-08-22"
rm -f "$TMP/month/.rolled-2026-08-22" "$TMP/owners/.rolled-2026-08-22"
ROLL_DOW=1 ROLL_HOUR=12 sh "$UC" roll 2026-08-22
out=$(cat "$TMP/rollups/1405-05.tsv" 2>/dev/null)
assert_contains "rollup has closed-day totals" "2026-08-22|Ali|1073741824|7700" "$out"

summary
