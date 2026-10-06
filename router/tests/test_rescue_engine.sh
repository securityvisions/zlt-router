#!/bin/sh
# Unit tests for router/x28/rescue-engine.sh
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
RE="$HERE/../x28/rescue-engine.sh"

PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Test 1: Pure decision logic - Hysteresis promote
d1=$(sh "$RE" decide 4 0 "auto" 1 2)
if [ "$d1" = "promote" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: promote decision expected, got $d1"
fi

# Test 2: Pure decision logic - Not enough dead streak
d2=$(sh "$RE" decide 3 0 "auto" 1 2)
if [ "$d2" = "hold" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: hold decision expected (dead < 4), got $d2"
fi

# Test 3: Pure decision logic - No alive rescue nodes available
d3=$(sh "$RE" decide 4 0 "auto" 1 0)
if [ "$d3" = "hold" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: hold decision expected (rescue_alive=0), got $d3"
fi

# Test 4: Pure decision logic - Demote back to auto after 10 ticks
d4=$(sh "$RE" decide 0 10 "rescue" 1 2)
if [ "$d4" = "demote" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: demote decision expected (alive >= 10), got $d4"
fi

# Test 5: Pure decision logic - Demote if rescue pool itself drained
d5=$(sh "$RE" decide 0 2 "rescue" 1 0)
if [ "$d5" = "demote" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: demote decision expected (rescue drained), got $d5"
fi

# Test 6: Bulk aliveness querying via jq mock
MOCK_JSON='{
  "proxies": {
    "auto": {
      "all": ["node1", "node2", "node3"],
      "now": "node1",
      "type": "URLTest"
    },
    "rescue": {
      "all": ["rc1", "rc2"],
      "now": "rc1",
      "type": "URLTest"
    },
    "node1": {"alive": true, "name": "node1"},
    "node2": {"alive": false, "name": "node2"},
    "node3": {"alive": true, "name": "node3"},
    "rc1": {"alive": false, "name": "rc1"},
    "rc2": {"alive": true, "name": "rc2"}
  }
}'

auto_alive=$(MOCK_PROXIES_JSON="$MOCK_JSON" sh "$RE" aliveness auto)
rescue_alive=$(MOCK_PROXIES_JSON="$MOCK_JSON" sh "$RE" aliveness rescue)

if [ "$auto_alive" = "2" ] && [ "$rescue_alive" = "1" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: bulk aliveness parsing: auto=$auto_alive rescue=$rescue_alive"
fi

# Test 7: Master switch
RESCUE_DIR="$TMP" sh "$RE" switch off >/dev/null
sw=$(RESCUE_DIR="$TMP" sh "$RE" switch status)
if [ "$sw" = "0" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: master switch toggle: $sw"
fi

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
