#!/bin/sh
# Unit tests: router/x28/x28-thermal.sh — thermal reader + overheat guard (fixture-tested).
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
THERMAL="$HERE/../x28/x28-thermal.sh"

PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

assert_eq() {
    if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 expect [$2] actual [$3]"; fi
}

# Fixture: two zones 68000 and 72000 -> max 72
mkdir -p "$TMP/z1" "$TMP/z2"
mkdir -p "$TMP/t"
echo "68000" > "$TMP/t/temp_0"
echo "72000" > "$TMP/t/temp_1"
out=$(THERMAL_FIXTURE_DIR="$TMP/t" sh "$THERMAL" read 2>/dev/null | tr -d ' \n')
assert_eq "max of two zones" "72" "$out"

# Fixture: single zone 81000 -> 81
rm -rf "$TMP/t" && mkdir -p "$TMP/t"
echo "81000" > "$TMP/t/temp_0"
out=$(THERMAL_FIXTURE_DIR="$TMP/t" sh "$THERMAL" read 2>/dev/null | tr -d ' \n')
assert_eq "single zone 81" "81" "$out"

# Fixture: no zones -> empty
rm -rf "$TMP/t" && mkdir -p "$TMP/empty"
out=$(THERMAL_FIXTURE_DIR="$TMP/empty" sh "$THERMAL" read 2>/dev/null | tr -d ' \n')
assert_eq "no zones empty" "" "$out"

# Overheated check: 76 > 75 threshold
mkdir -p "$TMP/hot"
echo "76000" > "$TMP/hot/temp_0"
THERMAL_FIXTURE_DIR="$TMP/hot" sh "$THERMAL" check >/dev/null 2>&1; rc=$?
assert_eq "overheated 76" "0" "$rc"
# 75 not overheated
mkdir -p "$TMP/warm"
echo "75000" > "$TMP/warm/temp_0"
THERMAL_FIXTURE_DIR="$TMP/warm" sh "$THERMAL" check >/dev/null 2>&1; rc=$?
assert_eq "not overheated 75" "1" "$rc"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
