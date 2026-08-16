#!/bin/sh
# Unit tests: router/dns-ensure.sh — DNS-upstream decision seam.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
D="$HERE/../dns-ensure.sh"

PASS=0; FAIL=0
ck() {  # ck <desc> <expected> <passwall_enabled> <stub_ok>
    local got
    got=$(sh "$D" --decision "$3" "$4")
    if [ "$got" = "$2" ]; then PASS=$((PASS+1)); else
        FAIL=$((FAIL+1)); echo "FAIL - $1: expect [$2] actual [$got]"; fi
}
ck "passwall owns dns"       "passwall" "1" "1"
ck "fail-open + stub"        "encrypted" "0" "1"
ck "fail-open, no stub"      "none"     "0" "0"
ck "enabled, no stub"        "passwall" "1" "0"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
