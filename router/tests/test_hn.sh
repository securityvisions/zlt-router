#!/bin/sh
# Unit tests: hnlib.sh — the shared home-network business module.
# The deep reader/pricing logic behind the bot, the telemetry snapshot, the
# billing report and the Router API. Tested at the module seam: fixtures in,
# key=value lines out — no router state.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
HN_LIB="$HERE/../hnlib.sh"
[ -f "$HN_LIB" ] || HN_LIB="$HERE/hnlib.sh"
. "$HN_LIB"

PASS=0; FAIL=0
assert_eq() {  # assert_eq <desc> <expected> <actual>
    if [ "$2" = "$3" ]; then
        PASS=$((PASS+1))
    else
        FAIL=$((FAIL+1))
        echo "FAIL - $1"
        printf '  expect: [%s]\n' "$2"
        printf '  actual: [%s]\n' "$3"
    fi
}
field() {  # field <key> — pull a key=value line's value
    sed -n "s/^$1=//p"
}
summary() {
    echo "PASS=$PASS FAIL=$FAIL"
    [ "$FAIL" -eq 0 ]
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# ── hn_balance_fields ─────────────────────────────────────────────────────────
cat > "$TMP/normal" <<EOF
📦 Samantel — 146.5 GB left across 1 plan(s)
Main: 150 GB · 146.5 GB left (97%) · expires 2027-08-05 (~363d)
+1 expired plan(s)

Drain ~3.5 GB/day → ~41d left (est. — ISP updates slowly)
EOF

out=$(hn_balance_fields "$TMP/normal")
assert_eq "normal: available" 1 "$(echo "$out" | field available)"
assert_eq "normal: total" 146.5 "$(echo "$out" | field total)"
assert_eq "normal: plans" 1 "$(echo "$out" | field plans)"
assert_eq "normal: quota" 150 "$(echo "$out" | field quota)"
assert_eq "normal: remain" 146.5 "$(echo "$out" | field remain)"
assert_eq "normal: pct" 97 "$(echo "$out" | field pct)"
assert_eq "normal: expires" 2027-08-05 "$(echo "$out" | field expires)"
assert_eq "normal: days" 363 "$(echo "$out" | field days)"
assert_eq "normal: expired" 1 "$(echo "$out" | field expired)"
assert_eq "normal: drain" "~3.5 GB/day → ~41d left" "$(echo "$out" | field drain)"

# ── hn_balance_field — the field accessor on hn_balance_fields output ─────────
assert_eq "field: total" 146.5 "$(hn_balance_field "$out" total)"
assert_eq "field: pct" 97 "$(hn_balance_field "$out" pct)"
assert_eq "field: remain" 146.5 "$(hn_balance_field "$out" remain)"
assert_eq "field: expires" 2027-08-05 "$(hn_balance_field "$out" expires)"
assert_eq "field: unknown -> empty" "" "$(hn_balance_field "$out" no_such_field)"

echo "No data packages found." > "$TMP/nodata"
out=$(hn_balance_fields "$TMP/nodata")
assert_eq "nodata: available" 0 "$(echo "$out" | field available)"
assert_eq "nodata: remain is empty" "" "$(echo "$out" | field remain)"

out=$(hn_balance_fields "$TMP/absent")
assert_eq "missing: available" 0 "$(echo "$out" | field available)"

# ── hn_balance_series — one reader for the sparkline (pipe) and history (rows) ─
mkdir -p "$TMP/balance-log"
cat > "$TMP/balance-log/2026-08.log" <<'EOF'
2026-08-06|146.5
2026-08-07|145.0
2026-08-08|143.2
EOF
cat > "$TMP/balance-log/2026-09.log" <<'EOF'
2026-09-01|140.1
2026-09-02|138.0
EOF
export HN_BALANCE_LOG_DIR="$TMP/balance-log"

assert_eq "series: rows chronological" "2026-08-06|146.5
2026-08-07|145.0
2026-08-08|143.2
2026-09-01|140.1
2026-09-02|138.0" "$(hn_balance_series 10 rows)"
assert_eq "series: rows last 3" "2026-08-08|143.2
2026-09-01|140.1
2026-09-02|138.0" "$(hn_balance_series 3 rows)"
assert_eq "series: pipe sparkline" "146.5|145.0|143.2|140.1|138.0" "$(hn_balance_series 5 pipe)"
assert_eq "series: pipe last 2" "140.1|138.0" "$(hn_balance_series 2 pipe)"

# a malformed line (no date, no numeric value) must be ignored by the filter
echo "garbage|line" >> "$TMP/balance-log/2026-09.log"
assert_eq "series: ignores malformed rows" "2026-08-06|146.5
2026-08-07|145.0
2026-08-08|143.2
2026-09-01|140.1
2026-09-02|138.0" "$(hn_balance_series 10 rows)"
unset HN_BALANCE_LOG_DIR

# ── hn_cost_table ────────────────────────────────────────────────────────────
cat > "$TMP/rows" <<EOF
iPhone|aa:bb:cc:dd:ee:ff|1073741824
laptop|96:04:e1:00:00:00|268435456
EOF

out=$(hn_cost_table 7700 1000 < "$TMP/rows")
assert_eq "cost: iphone row" "ROW|iPhone|aa:bb:cc:dd:ee:ff|1.0000|8000|80.0" "$(echo "$out" | sed -n '1p')"
assert_eq "cost: laptop row" "ROW|laptop|96:04:e1:00:00:00|0.2500|2000|20.0" "$(echo "$out" | sed -n '2p')"
assert_eq "cost: total line" "TOTAL|1.2500|10000" "$(echo "$out" | sed -n '3p')"

out=$(hn_cost_table 4620 1000 < "$TMP/rows")
assert_eq "cost friday: iphone" "ROW|iPhone|aa:bb:cc:dd:ee:ff|1.0000|5000|80.0" "$(echo "$out" | sed -n '1p')"
assert_eq "cost friday: total" "TOTAL|1.2500|6000" "$(echo "$out" | sed -n '3p')"

# ROUND must actually change the math: 0.7 GB at full rate = 5390 Toman
printf 'd|00:11:22:33:44:55|751619276\n' > "$TMP/half"
out=$(hn_cost_table 7700 1000 < "$TMP/half")
assert_eq "round 1000" "ROW|d|00:11:22:33:44:55|0.7000|5000|100.0" "$(echo "$out" | sed -n '1p')"
out=$(hn_cost_table 7700 2000 < "$TMP/half")
assert_eq "round 2000" "ROW|d|00:11:22:33:44:55|0.7000|6000|100.0" "$(echo "$out" | sed -n '1p')"

out=$(hn_cost_table 7700 1000 < /dev/null)
assert_eq "cost: empty input" "TOTAL|0.0000|0" "$out"

summary