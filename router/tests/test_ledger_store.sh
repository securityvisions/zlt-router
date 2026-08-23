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

summary
