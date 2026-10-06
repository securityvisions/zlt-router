#!/bin/sh
# Unit tests for router/device-unifier.sh
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
DU="$HERE/../device-unifier.sh"

PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export IDENTITIES_TSV="$TMP/device-identities.tsv"

# Test 1: Init defaults and lookup
sh "$DU" init >/dev/null
c1=$(sh "$DU" get "22:7d:f2:30:d3:3b")
c2=$(sh "$DU" get "42:08:7c:71:a1:b4")
if [ "$c1" = "Nothing-Phone-2" ] && [ "$c2" = "Nothing-Phone-2" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: expected Nothing-Phone-2 for both MACs, got $c1 and $c2"
fi

# Test 2: Auto-link new rotating MAC by hostname
sh "$DU" auto-link "11:22:33:44:55:66" "Nothing-Phone-2" "" "" >/dev/null
c_new=$(sh "$DU" get "11:22:33:44:55:66")
if [ "$c_new" = "Nothing-Phone-2" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: auto-link expected Nothing-Phone-2, got $c_new"
fi

# Test 3: Manual link
sh "$DU" link "99:88:77:66:55:44" "WIN10-PC" >/dev/null
c_pc=$(sh "$DU" get "99:88:77:66:55:44")
if [ "$c_pc" = "WIN10-PC" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: manual link expected WIN10-PC, got $c_pc"
fi

# Test 4: Unlink
sh "$DU" unlink "99:88:77:66:55:44" >/dev/null
if ! sh "$DU" get "99:88:77:66:55:44" >/dev/null 2>&1; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: expected unlinked MAC to return empty/fail"
fi

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
