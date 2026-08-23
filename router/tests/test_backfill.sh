#!/bin/sh
# Unit tests: device-granularity owner rollups + backfill.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
HN_LIB="$HERE/../hnlib.sh"
[ -f "$HN_LIB" ] || HN_LIB="$HERE/hnlib.sh"
BF="$HERE/../x28/x28-owner-backfill.sh"

PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n' "$2"; printf '  actual: [%s]\n' "$3"; fi; }
assert_contains() { if printf '%s' "$3" | grep -qF "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (missing: $2)"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/day" "$TMP/owners-d"
cat > "$TMP/owners.conf" <<'EOF'
aa:bb:cc:dd:ee:ff|Ali
11:22:33:44:55:66|Sara
EOF
# day file: known macs, unknown mac, malformed line
cat > "$TMP/day/2026-08-20" <<'EOF'
aa:bb:cc:dd:ee:ff|192.168.70.100|Phone|1073741824|0
11:22:33:44:55:66|192.168.70.101|Laptop|0|2147483648
de:ad:be:ef:00:01|192.168.70.102|Ghost|500000000|100
EOF

out=$(DAY_DIR="$TMP/day" OWNERS_D="$TMP/owners-d" HN_OWNERS_FILE="$TMP/owners.conf" \
      sh "$BF" run)
assert_contains "run reports backfilled date" "2026-08-20" "$out"
assert_contains "run summary present" "summary:" "$out"

f="$TMP/owners-d/2026-08-20"
[ -f "$f" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - rollup missing"; }
assert_contains "Ali row"        "Ali|aa:bb:cc:dd:ee:ff|1073741824|0" "$(cat $f)"
assert_contains "Sara row"       "Sara|11:22:33:44:55:66|0|2147483648" "$(cat $f)"
assert_contains "unknown -> unassigned" "unassigned|de:ad:be:ef:00:01|500000000|100" "$(cat $f)"
assert_eq "row count" "3" "$(wc -l < $f | tr -d ' ')"

# idempotent rerun: file untouched, summary shows zero new days
sum2=$(DAY_DIR="$TMP/day" OWNERS_D="$TMP/owners-d" HN_OWNERS_FILE="$TMP/owners.conf" \
       sh "$BF" run)
assert_contains "rerun converts nothing" "days=0" "$sum2"

# single-date mode + missing day file
r=$(DAY_DIR="$TMP/day" OWNERS_D="$TMP/owners-d" HN_OWNERS_FILE="$TMP/owners.conf" \
    sh "$BF" date 2026-08-20)
assert_eq "date mode existing -> 0" "0" "$r"
r=$(DAY_DIR="$TMP/day" OWNERS_D="$TMP/owners-d" HN_OWNERS_FILE="$TMP/owners.conf" \
    sh "$BF" date 1999-01-01)
assert_eq "date mode missing -> 0" "0" "$r"

summary
