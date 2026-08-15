#!/bin/sh
# Unit tests: router/vpshealth.sh — VPS health decision.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
V="$HERE/../vpshealth.sh"

PASS=0; FAIL=0
ck() {  # ck <desc> <expected> <panel> <sub> <ssh>
    local got
    got=$(sh "$V" --decision "$3" "$4" "$5")
    if [ "$got" = "$2" ]; then PASS=$((PASS+1)); else
        FAIL=$((FAIL+1)); echo "FAIL - $1: expect [$2] actual [$got]"; fi
}

ck "all up ok"      "OK"        "1" "1" "1"
ck "ssh down ok"    "OK"        "1" "1" "0"
ck "panel down"     "ALERT|down" "0" "1" "1"
ck "sub down"       "ALERT|down" "1" "0" "1"
ck "all down"       "ALERT|down" "0" "0" "0"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
