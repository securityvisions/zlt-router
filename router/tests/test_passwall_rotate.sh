#!/bin/sh
# Unit tests: router/passwall-failopen.sh — node-rotation chain logic.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
F="$HERE/../passwall-failopen.sh"

PASS=0; FAIL=0
ck() {  # ck <desc> <expected> <current>
    local got
    got=$(sh "$F" --next "$3")
    if [ "$got" = "$2" ]; then PASS=$((PASS+1)); else
        FAIL=$((FAIL+1)); echo "FAIL - $1: expect [$2] actual [$got]"; fi
}

ck "cdn_ws -> eFCgnGrZ"  "eFCgnGrZ" "cdn_ws"
ck "eFCgnGrZ -> hyst_vps" "hyst_vps" "eFCgnGrZ"
ck "hyst_vps -> via_x28" "via_x28" "hyst_vps"
ck "via_x28 is last (empty)" "" "via_x28"
ck "unknown current -> empty" "" "no_such_node"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
