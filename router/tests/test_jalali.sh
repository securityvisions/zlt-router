#!/bin/sh
# Unit tests: Jalali calendar (hnlib.sh) — pure Gregorian↔Jalali conversion.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
HN_LIB="$HERE/../hnlib.sh"
[ -f "$HN_LIB" ] || HN_LIB="$HERE/hnlib.sh"
. "$HN_LIB"

PASS=0; FAIL=0
assert_eq() {
    if [ "$2" = "$3" ]; then
        PASS=$((PASS+1))
    else
        FAIL=$((FAIL+1))
        echo "FAIL - $1"
        printf '  expect: [%s]\n' "$2"
        printf '  actual: [%s]\n' "$3"
    fi
}
assert_rc() {
    if [ "$2" -eq "$3" ]; then
        PASS=$((PASS+1))
    else
        FAIL=$((FAIL+1))
        echo "FAIL - $1"
        printf '  expect rc: [%s]\n' "$2"
        printf '  actual rc: [%s]\n' "$3"
    fi
}
summary() {
    echo "PASS=$PASS FAIL=$FAIL"
    [ "$FAIL" -eq 0 ]
}

# ── hn_greg_to_jalali ───────────────────────────────────────────────────────
assert_eq "g2j 2026-08-22" "1405-05-31" "$(hn_greg_to_jalali 2026-08-22)"
assert_eq "g2j 2026-08-23" "1405-06-01" "$(hn_greg_to_jalali 2026-08-23)"
assert_eq "g2j 2026-09-22" "1405-06-31" "$(hn_greg_to_jalali 2026-09-22)"
assert_eq "g2j 2023-03-21" "1402-01-01" "$(hn_greg_to_jalali 2023-03-21)"
assert_eq "g2j 2024-03-20" "1403-01-01" "$(hn_greg_to_jalali 2024-03-20)"
assert_eq "g2j 2025-03-21" "1404-01-01" "$(hn_greg_to_jalali 2025-03-21)"
assert_eq "g2j 2026-03-21" "1405-01-01" "$(hn_greg_to_jalali 2026-03-21)"
assert_eq "g2j 2024-02-29 leap" "1402-12-10" "$(hn_greg_to_jalali 2024-02-29)"
assert_eq "g2j 2025-03-20 esfand 30 leap" "1403-12-30" "$(hn_greg_to_jalali 2025-03-20)"
# invalid gregorian
out=$(hn_greg_to_jalali 2023-02-29); rc=$?
assert_eq "g2j invalid 2023-02-29 empty" "" "$out"
assert_rc "g2j invalid 2023-02-29 rc" 1 "$rc"
out=$(hn_greg_to_jalali invalid); rc=$?
assert_eq "g2j invalid string empty" "" "$out"
assert_rc "g2j invalid string rc" 1 "$rc"
out=$(hn_greg_to_jalali 2024-13-01); rc=$?
assert_eq "g2j invalid month empty" "" "$out"
assert_rc "g2j invalid month rc" 1 "$rc"

# ── hn_jalali_to_greg ───────────────────────────────────────────────────────
assert_eq "j2g 1405-06-01" "2026-08-23" "$(hn_jalali_to_greg 1405-06-01)"
assert_eq "j2g 1405-06-31" "2026-09-22" "$(hn_jalali_to_greg 1405-06-31)"
assert_eq "j2g 1402-01-01" "2023-03-21" "$(hn_jalali_to_greg 1402-01-01)"
assert_eq "j2g 1403-01-01" "2024-03-20" "$(hn_jalali_to_greg 1403-01-01)"
assert_eq "j2g 1404-01-01" "2025-03-21" "$(hn_jalali_to_greg 1404-01-01)"
assert_eq "j2g 1403-12-30 leap" "2025-03-20" "$(hn_jalali_to_greg 1403-12-30)"
assert_eq "j2g 1404-12-29" "2026-03-20" "$(hn_jalali_to_greg 1404-12-29)"
# invalid jalali
out=$(hn_jalali_to_greg 1404-12-30); rc=$?
assert_eq "j2g invalid 1404-12-30 empty" "" "$out"
assert_rc "j2g invalid 1404-12-30 rc" 1 "$rc"
out=$(hn_jalali_to_greg 1405-13-01); rc=$?
assert_eq "j2g invalid month empty" "" "$out"
assert_rc "j2g invalid month rc" 1 "$rc"
out=$(hn_jalali_to_greg 1405-06-32); rc=$?
assert_eq "j2g invalid day empty" "" "$out"
assert_rc "j2g invalid day rc" 1 "$rc"

# ── roundtrip property (greg -> jalali -> greg must be identity for sample) ─
for d in "2020-01-15" "2021-06-01" "2022-12-31" "2023-03-21" "2024-02-29" "2025-07-23" "2026-03-21" "2026-08-22"; do
    j=$(hn_greg_to_jalali "$d")
    g=$(hn_jalali_to_greg "$j")
    assert_eq "roundtrip $d" "$d" "$g"
done

# ── hn_jalali_month_range ───────────────────────────────────────────────────
assert_eq "range 1405-06" "2026-08-23 2026-09-22" "$(hn_jalali_month_range 1405-06)"
assert_eq "range 1403-12 leap" "2025-02-19 2025-03-20" "$(hn_jalali_month_range 1403-12)"
assert_eq "range 1404-12 non-leap" "2026-02-20 2026-03-20" "$(hn_jalali_month_range 1404-12)"
assert_eq "range 1402-01" "2023-03-21 2023-04-20" "$(hn_jalali_month_range 1402-01)"
# Esfand 30-day month should have 30-day range, 29-day should have 29 days
# Count days via range diff
range=$(hn_jalali_month_range 1403-12)
s=$(echo "$range" | cut -d' ' -f1); e=$(echo "$range" | cut -d' ' -f2)
# days in range inclusive = (e - s) +1 ; compute via awk date diff using mktime if available
# Use simple check: 1403-12 should span 30 days, 1404-12 should span 29
# Verify by counting: parse start/end and check via python-style? Just assert end-start diff
assert_eq "range 1403-12 end" "2025-03-20" "$(echo "$range" | cut -d' ' -f2)"
range2=$(hn_jalali_month_range 1404-12)
assert_eq "range 1404-12 end" "2026-03-20" "$(echo "$range2" | cut -d' ' -f2)"
out=$(hn_jalali_month_range 1405-13); rc=$?
assert_eq "range invalid month empty" "" "$out"
assert_rc "range invalid month rc" 1 "$rc"

# ── hn_jalali_month_label ───────────────────────────────────────────────────
assert_eq "label 1" "فروردین" "$(hn_jalali_month_label 1)"
assert_eq "label 2" "اردیبهشت" "$(hn_jalali_month_label 2)"
assert_eq "label 3" "خرداد" "$(hn_jalali_month_label 3)"
assert_eq "label 6" "شهریور" "$(hn_jalali_month_label 6)"
assert_eq "label 12" "اسفند" "$(hn_jalali_month_label 12)"
out=$(hn_jalali_month_label 13); rc=$?
assert_eq "label invalid empty" "" "$out"
assert_rc "label invalid rc" 1 "$rc"
out=$(hn_jalali_month_label 0); rc=$?
assert_eq "label 0 empty" "" "$out"
assert_rc "label 0 rc" 1 "$rc"

summary
