#!/bin/sh
# Unit tests: hn_link_state deep seam — one LinkState reader for all consumers.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
HN_LIB="$HERE/../hnlib.sh"
. "$HN_LIB"

PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Fixture: linkstate output (as x28link.sh would produce)
cat > "$TMP/link1" <<'EOF'
operator=IR - MCI Wap
plmn=43211
tech=5G(NSA)
signal=4
rsrp=-77
rsrp_5g=-92
band=n77
flow_dl=3441.61
flow_ul=243.88
EOF

# Test hn_link_state reads file and outputs all fields
HN_LINK_STATE_FILE="$TMP/link1" hn_link_state > "$TMP/out" 2>/dev/null
for k in operator plmn tech signal rsrp rsrp_5g band flow_dl flow_ul; do
    if grep -q "^$k=" "$TMP/out"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - missing $k"; fi
done
# Check values
grep -q "^operator=IR - MCI Wap$" "$TMP/out" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - operator value"; }
grep -q "^plmn=43211$" "$TMP/out" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - plmn value"; }

# Test hn_link_field still works via hn_link_state output
fields=$(cat "$TMP/out")
got=$(hn_link_field "$fields" "rsrp")
if [ "$got" = "-77" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - hn_link_field rsrp [$got]"; fi

# Test hn_link_decide — pure LinkPolicy (operator, tech, rsrp, rsrp_5g)
out=$(hn_link_decide "IR - MCI Wap" "5G(NSA)" "-77" "-92")
if [ "$out" = "OK" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - decide OK [$out]"; fi
out=$(hn_link_decide "Rightel" "4G" "-77" "-92")
if echo "$out" | grep -q "operator"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - decide drift [$out]"; fi
out=$(hn_link_decide "IR - MCI Wap" "5G(NSA)" "-96" "-92")
if echo "$out" | grep -q "degraded"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - decide degraded rsrp [$out]"; fi

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
