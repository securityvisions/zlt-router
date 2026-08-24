#!/bin/sh
# Unit tests: ledger-store — shared aggregation seam.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
HN_LIB="$HERE/../hnlib.sh"
[ -f "$HN_LIB" ] || HN_LIB="$HERE/hnlib.sh"
LS="$HERE/../x28/ledger-store.sh"

PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n' "$2"; printf '  actual: [%s]\n' "$3"; fi; }
assert_contains() { if printf '%s' "$3" | grep -qF "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (missing: $2)"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/owners-d"
printf 'RATE_FULL=7700\nRATE_FRIDAY=4620\n' > "$TMP/billing.conf"

cat > "$TMP/owners-d/2026-07-24" <<'EOF'
Ali|aa:bb:cc:dd:ee:01|1073741824|0
Sara|11:22:33:44:55:66|0|2147483648
EOF
cat > "$TMP/owners-d/2026-08-22" <<'EOF'
Ali|aa:bb:cc:dd:ee:ff|536870912|0
unassigned|de:ad:be:ef:00:01|1073741824|100
EOF

export USAGE_DIR="$TMP" HN_LIB="$HN_LIB"

# ── ledger_query ────────────────────────────────────────────────────────────
out=$(sh "$LS" query 1405-05)
assert_contains "query Ali present" "Ali" "$out"
assert_contains "query Sara present" "Sara" "$out"
assert_contains "query unassigned" "unassigned" "$out"
# total bytes: Ali 1.5G + 0.5G = 2G, Sara 2G, unassigned 1G → sorted desc
first=$(echo "$out" | head -1 | cut -f1)
assert_eq "query sorted desc (first=Sara)" "Sara" "$first"

# invalid month
sh "$LS" query bogus >/dev/null 2>&1; rc=$?
assert_eq "query invalid rc" "1" "$rc"

# empty month
mkdir -p "$TMP/empty/owners-d"
out=$(USAGE_DIR="$TMP/empty" sh "$LS" query 1405-01)
[ -z "$out" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - empty month should return nothing"; }

# ── ledger_rates ────────────────────────────────────────────────────────────
r=$(USAGE_DIR="$TMP" sh "$LS" rates)
assert_contains "rates full" "7700" "$r"
assert_contains "rates friday" "4620" "$r"

# ── ledger_day_rows ─────────────────────────────────────────────────────────
# rolled day: owners-d file passes through verbatim
out=$(sh "$LS" day-rows 2026-07-24)
assert_contains "day-rows rolled pass-through" "Ali|aa:bb:cc:dd:ee:01|1073741824|0" "$out"

# live today: no owners-d file yet → attribute day/ file via owners file
mkdir -p "$TMP/day"
printf 'aa:bb:cc:dd:ee:77|192.168.70.20|laptop|1073741824|0\n' > "$TMP/day/2026-08-23"
printf 'de:ad:be:ef:00:99|192.168.70.30|phone|0|536870912\n' >> "$TMP/day/2026-08-23"
printf 'AA:BB:CC:DD:EE:77|Ali\n' > "$TMP/owners.conf"
out=$(PEOPLE_TODAY=2026-08-23 HN_OWNERS_FILE="$TMP/owners.conf" sh "$LS" day-rows 2026-08-23)
assert_contains "day-rows live attributed" "Ali|aa:bb:cc:dd:ee:77|1073741824|0" "$out"
assert_contains "day-rows live unassigned fallback" "unassigned|de:ad:be:ef:00:99|0|536870912" "$out"

# live file exists but date is not today → ignored (stale day file)
out=$(PEOPLE_TODAY=2026-08-24 HN_OWNERS_FILE="$TMP/owners.conf" sh "$LS" day-rows 2026-08-23)
[ -z "$out" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - stale live day should be ignored"; }

# rolled file wins over live file for the same day
printf 'Ali|aa:bb:cc:dd:ee:77|1|1\n' > "$TMP/owners-d/2026-08-23"
out=$(PEOPLE_TODAY=2026-08-23 HN_OWNERS_FILE="$TMP/owners.conf" sh "$LS" day-rows 2026-08-23)
assert_contains "day-rows rolled wins over live" "Ali|aa:bb:cc:dd:ee:77|1|1" "$out"
rm -f "$TMP/owners-d/2026-08-23"

# ── ledger_query includes live today ────────────────────────────────────────
# 1405-06 spans 2026-08-23..2026-09-22; today=2026-08-23 has only a live file
out=$(PEOPLE_TODAY=2026-08-23 HN_OWNERS_FILE="$TMP/owners.conf" sh "$LS" query 1405-06)
assert_contains "query includes live today (Ali)" "Ali" "$out"

# ── dow_u — weekday seam (drives Friday discounted rates) ───────────────────
d=$( ( . "$LS"; dow_u 2026-08-21 ) )
assert_eq "dow_u Friday=5" "5" "$d"
d=$( ( . "$LS"; dow_u 2026-08-24 ) )
assert_eq "dow_u Monday=1" "1" "$d"
d=$( ( . "$LS"; dow_u 2026-08-22 ) )
assert_eq "dow_u Saturday=6" "6" "$d"
d=$( ( . "$LS"; dow_u 2026-08-23 ) )
assert_eq "dow_u Sunday=7" "7" "$d"

# ── ledger_rollup ───────────────────────────────────────────────────────────
# fixture month 1405-05 spans 2026-07-23..2026-08-22
# 2026-08-22 (Sat): Ali 0.5G=3850T, unassigned 1G+100B≈7700T
# 2026-07-24 (FRIDAY): Ali 1G at discounted rate = 4620T
printf 'Ali|aa:bb:cc:dd:ee:01|536870912|0\nunassigned|de:ad:be:ef:00:01|1073741824|100\n' > "$TMP/owners-d/2026-08-22"
out=$(sh "$LS" rollup 2026-08-22; cat "$TMP/rollups/1405-05.tsv")
assert_contains "rollup Ali 08-22" "2026-08-22|Ali|536870912|3850" "$out"
assert_contains "rollup unassigned 08-22" "2026-08-22|unassigned|1073741924|7700" "$out"
assert_contains "rollup Ali friday 07-24 discounted" "2026-07-24|Ali|1073741824|4620" "$out"

# idempotent: re-run produces byte-identical file
cp "$TMP/rollups/1405-05.tsv" "$TMP/rollups/.first"
sh "$LS" rollup 2026-08-22
cmp -s "$TMP/rollups/.first" "$TMP/rollups/1405-05.tsv" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - rollup not idempotent"; }

# live-today: rollup for the current month includes today's live rows
# (2026-08-23 is the FIRST day of Jalali month 1405-06)
printf 'aa:bb:cc:dd:ee:77|192.168.70.20|laptop|1073741824|0\n' > "$TMP/day/2026-08-23"
PEOPLE_TODAY=2026-08-23 HN_OWNERS_FILE="$TMP/owners.conf" sh "$LS" rollup 2026-08-23
out=$(cat "$TMP/rollups/1405-06.tsv")
assert_contains "rollup includes live today" "2026-08-23|Ali|1073741824|7700" "$out"

# rollup-all: regenerates every month that has owners-d history
rm -f "$TMP/rollups/1405-05.tsv"
sh "$LS" rollup-all
out=$(cat "$TMP/rollups/1405-05.tsv")
assert_contains "rollup-all regenerated" "2026-08-22|Ali|536870912|3850" "$out"

summary
