#!/bin/sh
# Unit tests for router/device-identifier.sh
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
DI="$HERE/../device-identifier.sh"

PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Test 1: Random MAC detection
r1=$(sh "$DI" is-random "a8:2b:dd:8c:cf:fc")
r2=$(sh "$DI" is-random "da:13:07:c4:1a:22")
if [ "$r1" = "hardware" ] && [ "$r2" = "random" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: random MAC detection expected hardware/random, got $r1/$r2"
fi

# Test 2: OUI Vendor lookup
v_lenovo=$(sh "$DI" oui "a8:2b:dd:8c:cf:fc")
v_samsung=$(sh "$DI" oui "c8:12:0b:32:7c:f2")
v_tplink=$(sh "$DI" oui "5c:a6:e6:df:91:d1")
if [ "$v_lenovo" = "Lenovo" ] && [ "$v_samsung" = "Samsung" ] && [ "$v_tplink" = "TP-Link" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: OUI vendor lookup: $v_lenovo, $v_samsung, $v_tplink"
fi

# Test 3: OS inference from Option 55 PRL
os_ios=$(sh "$DI" os "1,121,3,6,15,119,252" "" "")
os_android=$(sh "$DI" os "1,3,6,15,26,28,51,58,59,43" "" "")
os_win=$(sh "$DI" os "1,3,6,15,31,33,43,44,46,47,119,121,249,252" "" "")
if [ "$os_ios" = "iOS" ] && [ "$os_android" = "Android" ] && [ "$os_win" = "Windows" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: OS inference: ios=$os_ios, android=$os_android, win=$os_win"
fi

# Test 4: Identification with hardware OUI
lbl_hw=$(sh "$DI" identify "a8:2b:dd:8c:cf:fc" "" "" "")
if [ "$lbl_hw" = "[Lenovo] Device" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: hardware identification expected [Lenovo] Device, got $lbl_hw"
fi

# Test 5: Identification with randomized MAC + iOS PRL
lbl_rand_ios=$(sh "$DI" identify "da:13:07:c4:1a:22" "" "1,121,3,6,15,119,252" "")
if [ "$lbl_rand_ios" = "[iOS] Device-da:13:07" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: random iOS identification expected [iOS] Device-da:13:07, got $lbl_rand_ios"
fi

# Test 6: User manual override priority
echo "da:13:07:c4:1a:22 Parsa-Phone" > "$TMP/user-names"
lbl_override=$(USER_NAMES="$TMP/user-names" sh "$DI" identify "da:13:07:c4:1a:22" "" "1,121,3,6,15,119,252" "")
if [ "$lbl_override" = "Parsa-Phone" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: user override priority expected Parsa-Phone, got $lbl_override"
fi

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
