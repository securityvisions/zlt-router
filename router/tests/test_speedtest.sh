#!/bin/sh
# Unit tests: router/speedtest.sh — degradation decision + trend log.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
S="$HERE/../speedtest.sh"

PASS=0; FAIL=0
ck() {  # ck <desc> <expected> <mbps> [floor]
    local got
    if [ -n "$4" ]; then got=$(sh "$S" --decision "$3" "$4"); else got=$(sh "$S" --decision "$3"); fi
    if [ "$got" = "$2" ]; then PASS=$((PASS+1)); else
        FAIL=$((FAIL+1)); echo "FAIL - $1: expect [$2] actual [$got]"; fi
}

ck "fast link ok"   "OK"         "45.3"
ck "mid link ok"    "OK"         "15.0"
ck "slow alerts"    "ALERT|slow" "8.2"
ck "floor override" "ALERT|slow" "55.0" "60"
ck "at floor ok"    "OK"         "10.0"

# Decimal-time calc: 10,000,000 bytes in 12.84s ≈ 6.23 Mbps.
got=$(sh "$S" --calc 10000000 12.84)
[ "$got" = "6.23" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - calc decimal time: got [$got]"; }
# Integer time works too.
got=$(sh "$S" --calc 10000000 10)
[ "$got" = "8.00" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - calc integer time: got [$got]"; }

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
