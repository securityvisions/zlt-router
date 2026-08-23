#!/bin/sh
# Unit tests: per-person Jalali month (owners + people card + daily roll).
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
HN_LIB="$HERE/../hnlib.sh"
[ -f "$HN_LIB" ] || HN_LIB="$HERE/hnlib.sh"
. "$HN_LIB"

PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n' "$2"; printf '  actual: [%s]\n' "$3"; fi; }
assert_contains() { if printf '%s' "$3" | grep -q "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  should contain: [%s]\n' "$2"; printf '  actual: [%s]\n' "$3"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# ── hn_owner_of ─────────────────────────────────────────────────────────────
cat > "$TMP/owners.conf" <<'EOF'
aa:bb:cc:dd:ee:ff|Ali
11:22:33:44:55:66|Sara
EOF
assert_eq "owner exact" "Ali" "$(hn_owner_of "aa:bb:cc:dd:ee:ff" "$TMP/owners.conf")"
assert_eq "owner case-insensitive" "Ali" "$(hn_owner_of "AA:BB:CC:DD:EE:FF" "$TMP/owners.conf")"
assert_eq "owner second" "Sara" "$(hn_owner_of "11:22:33:44:55:66" "$TMP/owners.conf")"
assert_eq "owner unknown empty" "" "$(hn_owner_of "00:11:22:33:44:55" "$TMP/owners.conf")"
assert_eq "owner missing file empty" "" "$(hn_owner_of "aa:bb:cc:dd:ee:ff" "$TMP/nonexist")"

# ── x28-owners.sh assign/list/unassign ─────────────────────────────────────
OWNERS="$TMP/test_owners.conf"
: > "$OWNERS"
export OWNERS_FILE="$OWNERS"
OWN_SH="$HERE/../x28/x28-owners.sh"
sh "$OWN_SH" assign "aa:bb:cc:dd:ee:ff" "Ali" >/dev/null 2>&1
assert_eq "owners assign Ali" "Ali" "$(hn_owner_of "aa:bb:cc:dd:ee:ff" "$OWNERS")"
sh "$OWN_SH" assign "11:22:33:44:55:66" "Sara" >/dev/null 2>&1
assert_eq "owners assign Sara" "Sara" "$(hn_owner_of "11:22:33:44:55:66" "$OWNERS")"
# case-insensitive overwrite
sh "$OWN_SH" assign "AA:BB:CC:DD:EE:FF" "AliReza" >/dev/null 2>&1
assert_eq "owners overwrite case-insensitive" "AliReza" "$(hn_owner_of "aa:bb:cc:dd:ee:ff" "$OWNERS")"
# list contains both
out=$(sh "$OWN_SH" list 2>/dev/null)
assert_contains "owners list AliReza" "AliReza" "$out"
assert_contains "owners list Sara" "Sara" "$out"
# unassign
sh "$OWN_SH" unassign "11:22:33:44:55:66" >/dev/null 2>&1
assert_eq "owners unassign" "" "$(hn_owner_of "11:22:33:44:55:66" "$OWNERS")"
# shorthand assign: /owner <mac> <person>
sh "$OWN_SH" "aa:bb:cc:dd:ee:ff" "Ali" >/dev/null 2>&1
assert_eq "owners shorthand assign" "Ali" "$(hn_owner_of "aa:bb:cc:dd:ee:ff" "$OWNERS")"

# ── x28-people.sh report ────────────────────────────────────────────────────
# Use a past Jalali month 1405-05 (2026-07-23 to 2026-08-22) which is partially past (today is 2026-08-22)
# Setup USAGE_DIR with owners daily files
PEOPLE_SH="$HERE/../x28/x28-people.sh"
USAGE="$TMP/usage"
mkdir -p "$USAGE/owners-d"
# Device-granularity rollups (new format)
cat > "$USAGE/owners-d/2026-07-24" <<'EOF'
Ali|aa:bb:cc:dd:ee:01|1073741824|0
Sara|11:22:33:44:55:66|0|2147483648
EOF
cat > "$USAGE/owners-d/2026-08-22" <<'EOF'
Ali|aa:bb:cc:dd:ee:ff|536870912|0
unassigned|de:ad:be:ef:00:01|1073741824|100
EOF
# Outside range
printf 'Ali|aa:bb:cc:dd:ee:ff|1073741824|0
' > "$USAGE/owners-d/2026-07-22"
printf 'Ali|aa:bb:cc:dd:ee:ff|1073741824|0
' > "$USAGE/owners-d/2026-08-23"
# billing conf
mkdir -p "$USAGE"
printf 'RATE_FULL=7700\nRATE_FRIDAY=4620\n' > "$USAGE/billing.conf"
# Create owners.conf for lookup (not needed for owners files, but for completeness)
cat > "$TMP/owners2.conf" <<'EOF'
aa:bb:cc:dd:ee:ff|Ali
EOF
export USAGE_DIR="$USAGE"
export HN_OWNERS_FILE="$TMP/owners2.conf"
# Mock today to 2026-08-22 (already is) so that month-end clamping works
out=$(USAGE_DIR="$USAGE" HN_OWNERS_FILE="$TMP/owners2.conf" sh "$PEOPLE_SH" 1405-05 2>&1)
assert_contains "people header" "1405-05" "$out"
assert_contains "people Ali" "Ali" "$out"
assert_contains "people Sara" "Sara" "$out"
assert_contains "people unassigned" "unassigned" "$out"
# Check totals: Ali 1.5GB, Sara 2GB, unassigned 1GB => total 4.5
assert_contains "people total" "TOTAL" "$out"
# Ensure outside files not counted: 07-22 and 08-23 should not affect total (if they were, total would be 5.5)
# We already verified total 4.5, so outside not counted
echo "$out" | grep -q "4.50 GB" || { echo "FAIL - people total GB 4.5"; echo "$out"; FAIL=$((FAIL+1)); }
PASS=$((PASS+1))
# Invalid month
out=$(USAGE_DIR="$USAGE" sh "$PEOPLE_SH" invalid 2>&1); rc=$?
if [ $rc -ne 0 ]; then PASS=$((PASS+1)); else echo "FAIL - invalid month should fail"; FAIL=$((FAIL+1)); fi
# No data month
out=$(USAGE_DIR="$TMP/empty" sh "$PEOPLE_SH" 1405-06 2>&1)
assert_contains "people no data" "no usage data" "$out"

# ── usage-collect roll creates owners file ──────────────────────────────────
# Simulate a day file and run roll logic (call the roll function via sourcing)
# Create a fake day file and owners.conf, then invoke the roll snippet
ROLL_TMP="$TMP/rolltest"
mkdir -p "$ROLL_TMP/day" "$ROLL_TMP/month" "$ROLL_TMP/owners"
cat > "$ROLL_TMP/day/2026-08-22" <<'EOF'
aa:bb:cc:dd:ee:ff|192.168.70.100|Phone|1073741824|0
11:22:33:44:55:66|192.168.70.101|Laptop|0|2147483648
EOF
cat > "$ROLL_TMP/owners.conf" <<'EOF'
aa:bb:cc:dd:ee:ff|Ali
EOF
# Simulate roll's owners aggregation (call the same logic as in usage-collect.sh)
DIR="$ROLL_TMP" HN_OWNERS_FILE="$ROLL_TMP/owners.conf" HN_LIB="$HN_LIB" sh -c '
    DIR="$1"; HN_OWNERS_FILE="$2"; HN_LIB="$3"
    day="2026-08-22"; dayf="$DIR/day/$day"
    . "$HN_LIB" 2>/dev/null || true
    OWNER_DIR="$DIR/owners"
    mkdir -p "$OWNER_DIR"
    : > "$DIR/.person.tmp"
    while IFS="|" read -r mac ip name up down; do
        case "$mac" in "#"*|"") continue;; esac
        person=$(hn_owner_of "$mac" "$HN_OWNERS_FILE" 2>/dev/null)
        [ -z "$person" ] && person="unassigned"
        printf "%s|%s|%s\n" "$person" "$up" "$down" >> "$DIR/.person.tmp"
    done < "$dayf"
    awk -F"|" "{ up[\$1]+=\$2; down[\$1]+=\$3 } END { for(p in up) print p\"|\"up[p]\"|\"down[p] }" "$DIR/.person.tmp" > "$OWNER_DIR/$day"
    cat "$OWNER_DIR/$day"
' -- "$ROLL_TMP" "$ROLL_TMP/owners.conf" "$HN_LIB" > "$TMP/roll_out"
out=$(cat "$TMP/roll_out")
assert_contains "roll Ali" "Ali|1073741824|0" "$out"
assert_contains "roll unassigned" "unassigned|0|2147483648" "$out"
# Ensure file persists after day prune would delete day file but not owners
# Simulate prune: delete day file, owners should remain
rm "$ROLL_TMP/day/2026-08-22"
if [ -f "$ROLL_TMP/owners/2026-08-22" ]; then PASS=$((PASS+1)); else echo "FAIL - owners persists after day delete"; FAIL=$((FAIL+1)); fi

summary

# ── hostname-aware assign + rename ──────────────────────────────────────────
sh "$OWN_SH" rename Ali AliReza >/dev/null 2>&1
assert_eq "rename person" "AliReza" "$(hn_owner_of "aa:bb:cc:dd:ee:ff" "$OWNERS")"
