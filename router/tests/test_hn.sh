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

# --- cooldown helper (shared alert throttle: the seam for all degraded alerts) ---
NOW=$(date +%s)
: > "$TMP/cd.state"
assert_eq "cooldown: no stamp -> ok" "0" "$(hn_cooldown_ok "$TMP/cd.state" 300 alert; echo $?)"
# Stamp 400s ago with a 300s cooldown -> out of cooldown.
echo "alert $((NOW - 400))" > "$TMP/cd.state"
assert_eq "cooldown: older than cd -> ok" "0" "$(hn_cooldown_ok "$TMP/cd.state" 300 alert; echo $?)"
# Stamp 100s ago with a 300s cooldown -> still cooling.
echo "alert $((NOW - 100))" > "$TMP/cd.state"
assert_eq "cooldown: within cd -> not ok" "1" "$(hn_cooldown_ok "$TMP/cd.state" 300 alert; echo $?)"
# Actions are independent: a fresh "fix" stamp must not throttle "alert".
echo "alert $((NOW - 400))" > "$TMP/cd.state"
echo "fix $NOW" >> "$TMP/cd.state"
assert_eq "cooldown: actions independent" "0" "$(hn_cooldown_ok "$TMP/cd.state" 300 alert; echo $?)"
assert_eq "cooldown: other action cooled" "1" "$(hn_cooldown_ok "$TMP/cd.state" 300 fix; echo $?)"
# Missing state file -> out of cooldown.
assert_eq "cooldown: missing state file" "0" "$(hn_cooldown_ok "$TMP/nonexistent" 300 alert; echo $?)"
# Note appends a stamp line.
: > "$TMP/note.state"
hn_cooldown_note "$TMP/note.state" degraded
hn_cooldown_note "$TMP/note.state" degraded
assert_eq "note: stamps written" "2" "$(grep -c '^degraded ' "$TMP/note.state")"
assert_eq "note: stamp is recent (still cooling)" "1" "$(hn_cooldown_ok "$TMP/note.state" 999999 degraded; echo $?)"

# --- link-quality module (passive throughput, decision, mbps calc) ---
assert_eq "calc: bytes/seconds" "6.23" "$(hn_mbps_calc 10000000 12.84)"
assert_eq "calc: integer time" "8.00" "$(hn_mbps_calc 10000000 10)"
assert_eq "calc: zero time" "0" "$(hn_mbps_calc 10000000 0)"

# Passive from telemetry total_gb deltas (0.5 GB over 1h = 1.19 Mbps); must
# handle the real '%F %H:%M' timestamp and tolerate the trailing quality fields.
printf '2026-08-15 22:00|10.0000|5.0|up\n2026-08-15 23:00|10.5000|5.0|up|0.30|1.19|cdn_ws\n' > "$TMP/telemetry"
assert_eq "passive: two rows" "1.19" "$(hn_q_passive_mbps "$TMP/telemetry")"
printf '2026-08-15 22:00|10.0000|5.0|up\n' > "$TMP/one"
assert_eq "passive: one row" "0" "$(hn_q_passive_mbps "$TMP/one")"
: > "$TMP/empty"
assert_eq "passive: empty log" "0" "$(hn_q_passive_mbps "$TMP/empty")"
assert_eq "passive: missing file" "0" "$(hn_q_passive_mbps "$TMP/nonexistent")"

# Telemetry row builder — existing fields first (old readers keep parsing),
# quality fields trail. The snap.sh format guard.
assert_eq "telemetry row" "2026-08-15 22:00|10.500|5.0|up|0.34|1.19|cdn_ws" \
    "$(hn_telemetry_row "2026-08-15 22:00" "10.500" "5.0" "up" "0.34" "1.19" "cdn_ws")"
assert_eq "telemetry row defaults" "2026-08-15 22:00|10.500|5.0|up|0|0|" \
    "$(hn_telemetry_row "2026-08-15 22:00" "10.500" "5.0" "up")"

# Cost forecast (burn-rate projection + budget decision).
assert_eq "forecast gb: linear" "30.00" "$(hn_forecast_gb 10 10 30)"
assert_eq "forecast gb: none elapsed" "0" "$(hn_forecast_gb 10 0 30)"
assert_eq "forecast gb: none so far" "0" "$(hn_forecast_gb 0 10 30)"
assert_eq "forecast cost" "231000" "$(hn_forecast_cost 30 7700)"
assert_eq "budget: under -> ok" "OK" "$(hn_budget_decision 250000 300000)"
assert_eq "budget: at threshold -> alert" "ALERT|budget" "$(hn_budget_decision 300000 300000)"
assert_eq "budget: over -> alert" "ALERT|budget" "$(hn_budget_decision 320000 300000)"

# Friday offload: days until the discount window (dow 1=Mon..7=Sun, Friday=5).
assert_eq "friday: today" "0" "$(hn_days_until_friday 5)"
assert_eq "friday: tomorrow" "1" "$(hn_days_until_friday 4)"
assert_eq "friday: saturday" "6" "$(hn_days_until_friday 6)"
assert_eq "friday: monday" "4" "$(hn_days_until_friday 1)"
assert_eq "friday: sunday" "5" "$(hn_days_until_friday 7)"

# Decision: sample below floor -> degraded; latency catches it when sample unusable.
assert_eq "q: sample healthy" "OK" "$(hn_q_decision 0.3 12.5 10 2.0)"
assert_eq "q: sample degraded" "ALERT|degraded" "$(hn_q_decision 0.3 6.5 10 2.0)"
assert_eq "q: at floor ok" "OK" "$(hn_q_decision 0.3 10.0 10 2.0)"
assert_eq "q: no sample, latency ok" "OK" "$(hn_q_decision 0.3 '' 10 2.0)"
assert_eq "q: no sample, latency bad" "ALERT|degraded" "$(hn_q_decision 5.0 '' 10 2.0)"
assert_eq "q: unknown -> ok" "OK" "$(hn_q_decision '' '' 10 2.0)"
assert_eq "q: failed sample + bad latency" "ALERT|degraded" "$(hn_q_decision 3.0 0 10 2.0)"
assert_eq "q: ceiling honored" "OK" "$(hn_q_decision 2.0 '' 10 2.0)"

# Suspicion gate — the probing-budget rule: spend a bandwidth sample only when
# a cheap signal suggests degradation (used-but-slow passive, or high latency).
assert_eq "susp: used but slow" "1" "$(hn_q_suspicious 0.3 6.0 2.0 10)"
assert_eq "susp: high latency" "1" "$(hn_q_suspicious 3.0 12.0 2.0 10)"
assert_eq "susp: healthy" "0" "$(hn_q_suspicious 0.3 12.0 2.0 10)"
assert_eq "susp: idle hour" "0" "$(hn_q_suspicious 0.3 0 2.0 10)"
assert_eq "susp: no data" "0" "$(hn_q_suspicious '' '' 2.0 10)"
assert_eq "susp: no latency, used slow" "1" "$(hn_q_suspicious '' 6.0 2.0 10)"
assert_eq "susp: at floor not suspicious" "0" "$(hn_q_suspicious 0.3 10.0 2.0 10)"

summary