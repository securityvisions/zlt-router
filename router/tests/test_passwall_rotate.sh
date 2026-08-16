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

# Quality-aware rotation: ROTATE on the 2nd consecutive degraded check
# (hysteresis against a single noisy sample); STAY otherwise.
qc() {  # qc <desc> <expected> <qf_count> <sample>
    local got
    got=$(sh "$F" --qrotate "$3" "$4")
    if [ "$got" = "$2" ]; then PASS=$((PASS+1)); else
        FAIL=$((FAIL+1)); echo "FAIL - $1: expect [$2] actual [$got]"; fi
}
qc "first degraded check stays"  "STAY|degraded" "0" "6.5"
qc "second degraded rotates"     "ROTATE"        "1" "6.5"
qc "still degraded rotates"      "ROTATE"        "3" "6.5"
qc "healthy resets"              "STAY|ok"       "3" "12.0"
qc "at floor ok"                 "STAY|ok"       "3" "10.0"
qc "no sample -> ok"             "STAY|ok"       "3" ""
qc "zero sample -> ok"           "STAY|ok"       "3" "0"

# Auto-failback: return to the preferred node on the 2nd consecutive healthy
# check (hysteresis); reset when the preferred is unhealthy or we're already
# on it.
fb() {  # fb <desc> <expected> <fb_count> <on_preferred> <pref_healthy>
    local got
    got=$(sh "$F" --failback "$3" "$4" "$5")
    if [ "$got" = "$2" ]; then PASS=$((PASS+1)); else
        FAIL=$((FAIL+1)); echo "FAIL - $1: expect [$2] actual [$got]"; fi
}
fb "on preferred nothing to do" "NONE"     "3" "1" "1"
fb "preferred still down resets" "RESET"   "3" "0" "0"
fb "first healthy check counts" "COUNT"    "0" "0" "1"
fb "second healthy failbacks"   "FAILBACK" "1" "0" "1"
fb "still healthy fails back"   "FAILBACK" "3" "0" "1"
fb "off fallback, no data"      "RESET"    "2" "0" ""

# Escalation ladder: node rung exhausted -> operator re-selection -> fail-open.
esc() {  # esc <desc> <expected> <all_nodes_degraded> <opstate> <quality_bad>
    local got
    got=$(sh "$F" --escalate "$3" "$4" "$5")
    if [ "$got" = "$2" ]; then PASS=$((PASS+1)); else
        FAIL=$((FAIL+1)); echo "FAIL - $1: expect [$2] actual [$got]"; fi
}
esc "quality fine, nothing to do"    "NONE"     "1" "none"   "0"
esc "nodes remain, do not escalate"  "NONE"     "0" "none"   "1"
esc "first exhaustion -> operator"   "OPERATOR" "1" "none"   "1"
esc "operator in grace -> wait"      "WAIT"     "1" "fresh"  "1"
esc "operator grace passed -> open"  "FAILOPEN" "1" "stale"  "1"
esc "unknown opstate -> fail open"   "FAILOPEN" "1" "bogus"  "1"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
