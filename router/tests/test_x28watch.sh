#!/bin/sh
# Unit tests: router/x28watch.sh — link stickiness/degradation decision.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
W="$HERE/../x28watch.sh"

PASS=0; FAIL=0
ck() {  # ck <desc> <expected> <operator> <tech> <rsrp> <rsrp5g>
    local got
    got=$(X28_PREF_OPERATOR=MCI X28_RSRP_BAD=-95 X28_RSRP5G_BAD=-100 sh "$W" --check "$3" "$4" "$5" "$6")
    if [ "$got" = "$2" ]; then PASS=$((PASS+1)); else
        FAIL=$((FAIL+1)); echo "FAIL - $1: expect [$2] actual [$got]"; fi
}

# On MCI, healthy signal -> OK
ck "mci healthy"       "OK"          "IR - MCI Wap" "5G(NSA)" "-77" "-92"
ck "mci 4g healthy"    "OK"          "IR - MCI Wap" "4G"      "-80" ""
# Drifted to another operator -> FIX
ck "drift rightel"     "FIX|operator" "Rightel"      "4G"      "-89" ""
ck "drift irancell"    "FIX|operator" "MTN Irancell" "5G(NSA)" "-70" "-88"
# On MCI but weak signal -> ALERT (RSRP <= -95)
ck "mci weak rsrp"     "ALERT|degraded" "IR - MCI Wap" "5G(NSA)" "-97" "-100"
ck "mci borderline"    "ALERT|degraded" "IR - MCI Wap" "4G"     "-95" ""
# No RSRP reported -> OK (nothing to judge degradation on)
ck "mci no rsrp"       "OK"          "IR - MCI Wap" "5G(NSA)" ""    ""
# LTE anchor fine but 5G NR degraded -> ALERT (exercises rsrp_5g)
ck "mci weak nr"       "ALERT|degraded" "IR - MCI Wap" "5G(NSA)" "-80" "-105"
ck "mci nr ok"         "OK"          "IR - MCI Wap" "5G(NSA)" "-80" "-92"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
