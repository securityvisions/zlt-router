#!/bin/sh
# Unit tests for router/telemetry-engine.sh
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
TE="$HERE/../telemetry-engine.sh"

PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Test 1: Perfect health score (100 | Excellent)
res1=$(sh "$TE" score "-75" "1" "proxy" "30" "0" "0.5" "50")
if [ "$res1" = "100|Excellent|25|35|20|20" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: perfect score expected 100|Excellent|25|35|20|20, got $res1"
fi

# Test 2: RSRP degradation (-98 dBm -> 12 pts)
res2=$(sh "$TE" score "-98" "1" "proxy" "30" "0" "0.5" "50")
score2=$(printf '%s' "$res2" | cut -d'|' -f1)
link2=$(printf '%s' "$res2" | cut -d'|' -f3)
if [ "$score2" = "87" ] && [ "$link2" = "12" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: rsrp degradation score: $res2"
fi

# Test 3: Operator drift penalty (-10 pts from link)
res3=$(sh "$TE" score "-75" "0" "proxy" "30" "0" "0.5" "50")
link3=$(printf '%s' "$res3" | cut -d'|' -f3)
if [ "$link3" = "15" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: operator drift penalty: link=$link3"
fi

# Test 4: Proxy watchdog fail_open / direct mode (10 pts)
res4=$(sh "$TE" score "-75" "1" "direct" "30" "0" "0.5" "50")
proxy4=$(printf '%s' "$res4" | cut -d'|' -f4)
if [ "$proxy4" = "10" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: proxy direct mode: proxy=$proxy4"
fi

# Test 5: Severely degraded condition (Poor)
res5=$(sh "$TE" score "-105" "0" "dead" "200" "10" "3.0" "95")
score5=$(printf '%s' "$res5" | cut -d'|' -f1)
band5=$(printf '%s' "$res5" | cut -d'|' -f2)
if [ "$score5" -le 10 ] && [ "$band5" = "Poor" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: severely degraded score: $res5"
fi

# Test 6: Snapshot JSON structure
snap=$(TELEMETRY_DIR="$TMP" sh "$TE" snapshot --json)
if printf '%s\n' "$snap" | grep -q '"score":' && \
   printf '%s\n' "$snap" | grep -q '"subsystems":{' && \
   printf '%s\n' "$snap" | grep -q '"link":{'; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: snapshot JSON format: $snap"
fi

# Test 7: Hourly tick and history read
TELEMETRY_DIR="$TMP" sh "$TE" hourly-tick >/dev/null
hist=$(TELEMETRY_DIR="$TMP" sh "$TE" history 5)
if printf '%s\n' "$hist" | grep -q '"score":'; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: history format: $hist"
fi

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
