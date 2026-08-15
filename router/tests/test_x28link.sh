#!/bin/sh
# Unit tests: router/x28/linkstate.sh — normalized X28 link state from fixtures.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
LS="$HERE/../x28/linkstate.sh"

PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Fixture: X28 dashboard (cmd 401) — MCI 5G(NSA), RSRP -77 / NR -92, signal 4.
cat > "$TMP/cmd401.json" <<'EOF'
{"success":true,"cmd":401,"networkMode":"1C","flightMode":"0","network_operator":"IR - MCI Wap","network_type_str":"5G(NSA)","signal_lvl":"4","RSRP":"-77","RSRP_5G":"-92","flow_dl":"3441.61","flow_ul":"243.88","mon_total_flow":"298157.75"}
EOF
# Fixture: sys status (cmd 113).
cat > "$TMP/cmd113.json" <<'EOF'
{"success":true,"cmd":113,"network_type_str":"5G(NSA)","signal_lvl":"4","network_operator":"IR - MCI Wap","network_status":"1"}
EOF
# Fixture: AT+COPS? (cmd 270).
cat > "$TMP/cmd270.json" <<'EOF'
{"success":true,"cmd":270,"message":"success","flag":"  +COPS: 0,2,'43211',13    OK  "}
EOF

out=$(X28_FIXTURE_DIR="$TMP" sh "$LS")

assert_field() {  # assert_field <name> <expected>
    local v
    v=$(printf '%s\n' "$out" | sed -n "s/^$1=//p" | head -1)
    if [ "$v" = "$2" ]; then PASS=$((PASS+1)); else
        FAIL=$((FAIL+1)); echo "FAIL - $1: expect [$2] actual [$v]"; fi
}

assert_field operator "IR - MCI Wap"
assert_field tech "5G(NSA)"
assert_field signal "4"
assert_field rsrp "-77"
assert_field rsrp_5g "-92"
assert_field flow_dl "3441.61"
assert_field plmn "43211"
assert_field band ""

# Fixture: Rightel 4G, no 5G — fields must reflect the weaker link.
cat > "$TMP/cmd401.json" <<'EOF'
{"success":true,"cmd":401,"networkMode":"1C","network_operator":"Rightel","network_type_str":"4G","signal_lvl":"3","RSRP":"-93","RSRP_5G":"","flow_dl":"100.5","flow_ul":"40.2"}
EOF
cat > "$TMP/cmd270.json" <<'EOF'
{"success":true,"cmd":270,"message":"success","flag":"  +COPS: 0,2,'43220',7    OK  "}
EOF
out=$(X28_FIXTURE_DIR="$TMP" sh "$LS")
assert_field operator "Rightel"
assert_field tech "4G"
assert_field rsrp_5g ""
assert_field plmn "43220"

# Fixture: API unreachable — error marker, non-zero exit.
out=$(X28_FIXTURE_DIR="$TMP/nonexistent" sh "$LS" 2>/dev/null); rc=$?
printf '%s\n' "$out" | grep -q "error=api_unreachable" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - unreachable marker"; }
[ "$rc" -ne 0 ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - unreachable exit code"; }

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
