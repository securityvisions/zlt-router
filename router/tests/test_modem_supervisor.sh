#!/bin/sh
# Unit tests for router/x28/modem-supervisor.sh
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
MS="$HERE/../x28/modem-supervisor.sh"

PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Fixture setup
cat > "$TMP/cmd401.json" <<'EOF'
{"success":true,"cmd":401,"networkMode":"1C","flightMode":"0","network_operator":"IR - MCI Wap","network_type_str":"5G(NSA)","signal_lvl":"4","RSRP":"-77","RSRP_5G":"-92","flow_dl":"3441.61","flow_ul":"243.88","mon_total_flow":"298157.75"}
EOF

cat > "$TMP/cmd270.json" <<'EOF'
{"success":true,"cmd":270,"message":"success","flag":"  +COPS: 0,2,'43211',13    OK  "}
EOF

# Test 1: Status text output
out=$(X28_FIXTURE_DIR="$TMP" sh "$MS" status)
op=$(printf '%s\n' "$out" | sed -n 's/^operator=//p')
plmn=$(printf '%s\n' "$out" | sed -n 's/^plmn=//p')
sig=$(printf '%s\n' "$out" | sed -n 's/^signal=//p')

if [ "$op" = "IR - MCI Wap" ] && [ "$plmn" = "43211" ] && [ "$sig" = "4" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: status text parsing: op=$op plmn=$plmn sig=$sig"
fi

# Test 2: Status JSON output
json=$(X28_FIXTURE_DIR="$TMP" sh "$MS" status --json)
case "$json" in
    *'"operator":"IR - MCI Wap"'*'"signal":4'*'"plmn":"43211"'*)
        PASS=$((PASS + 1))
        ;;
    *)
        FAIL=$((FAIL + 1))
        echo "FAIL: status json parsing: $json"
        ;;
esac

# Test 3: Decision logic (Operator drift)
d_ok=$(sh "$MS" check "IR - MCI Wap" "5G(NSA)" "-77" "-92")
d_drift=$(sh "$MS" check "Rightel" "4G" "-85" "")
d_deg=$(sh "$MS" check "IR - MCI Wap" "5G(NSA)" "-98" "-105")

if [ "$d_ok" = "OK" ] && [ "$d_drift" = "FIX|operator" ] && [ "$d_deg" = "ALERT|degraded" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: check decisions: ok=$d_ok drift=$d_drift deg=$d_deg"
fi

# Test 4: Cooldown & storm guard in dry-run
ST="$TMP/state"
mkdir -p "$ST"
# Last switch 100s ago (within 600s cooldown)
echo $(( $(date +%s) - 100 )) > "$ST/lastswitch"

res_cd=$(MODEM_STATE_DIR="$ST" sh "$MS" switch 43220)
if [ "$res_cd" = "ERROR: in cooldown" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: cooldown not enforced: $res_cd"
fi

# Test 5: Storm guard (3 switches within last hour)
rm -f "$ST/lastswitch"
t=$(date +%s)
touch "$ST/sw.$((t - 100))" "$ST/sw.$((t - 200))" "$ST/sw.$((t - 300))"
res_sg=$(MODEM_STATE_DIR="$ST" sh "$MS" switch 43220)
if [ "$res_sg" = "ERROR: storm guard (3/hr)" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: storm guard not enforced: $res_sg"
fi

# Test 6: Dry-run switch when cooldown & storm guard clear
rm -rf "$ST"
mkdir -p "$ST"
res_dry=$(MODEM_STATE_DIR="$ST" WATCHDOG_DRYRUN=1 sh "$MS" switch 43220)
if [ "$res_dry" = "DRYRUN: switch 43220" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: dry-run switch: $res_dry"
fi

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
