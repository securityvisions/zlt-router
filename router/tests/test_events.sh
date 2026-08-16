#!/bin/sh
# Unit tests: the Network Event log (glossary: Network Event, Network Event log).
# The shared recorder (hn_event_record) + reader (hn_event_list) in hnlib.sh,
# and the /events API endpoint. Seam: fixtures in (event catalog + a log file),
# event lines / JSON out — no router state.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
HN_LIB="$HERE/../hnlib.sh"
[ -f "$HN_LIB" ] || HN_LIB="$HERE/hnlib.sh"
. "$HN_LIB"

PASS=0; FAIL=0
assert_eq() {  # assert_eq <desc> <expected> <actual>
    if [ "$2" = "$3" ]; then
        PASS=$((PASS+1))
    else
        FAIL=$((FAIL+1))
        echo "FAIL - $1"
        printf '  expect: [%s]\n' "$2"
        printf '  actual: [%s]\n' "$3"
    fi
}
assert_json_eq() {  # assert_json_eq <desc> <expected> <actual>  (jq-canonicalized)
    local e a
    if ! printf '%s' "$3" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
        FAIL=$((FAIL+1)); echo "FAIL - $1"; echo '  actual is NOT strictly valid JSON:'; echo "$3"; return
    fi
    e=$(printf '%s' "$2" | jq -cS 'walk(if type=="number" then .+0 else . end)' 2>/dev/null)
    a=$(printf '%s' "$3" | jq -cS 'walk(if type=="number" then .+0 else . end)' 2>/dev/null)
    assert_eq "$1" "$e" "$a"
}
summary() {
    echo "PASS=$PASS FAIL=$FAIL"
    [ "$FAIL" -eq 0 ]
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# ── hn_event_catalog — the event kind vocabulary ──────────────────────────────
assert_eq "catalog: internet_down is internet|critical" "internet|critical" "$(hn_event_meta internet_down)"
assert_eq "catalog: node_rotated is internet|warning" "internet|warning" "$(hn_event_meta node_rotated)"
assert_eq "catalog: device_joined is device|info" "device|info" "$(hn_event_meta device_joined)"
assert_eq "catalog: device_blocked is device|warning" "device|warning" "$(hn_event_meta device_blocked)"
assert_eq "catalog: device_approved is device|info" "device|info" "$(hn_event_meta device_approved)"
assert_eq "catalog: proxy_changed is proxy|info" "proxy|info" "$(hn_event_meta proxy_changed)"
assert_eq "catalog: package_threshold is package|warning" "package|warning" "$(hn_event_meta package_threshold)"
assert_eq "catalog: quality_degraded is internet|warning" "internet|warning" "$(hn_event_meta quality_degraded)"
assert_eq "catalog: quality_recovered is internet|info" "internet|info" "$(hn_event_meta quality_recovered)"
assert_eq "catalog: router_rebooted is router|critical" "router|critical" "$(hn_event_meta router_rebooted)"
assert_eq "catalog: dns_unhealthy is security|warning" "security|warning" "$(hn_event_meta dns_unhealthy)"
assert_eq "catalog: internet_up is internet|info" "internet|info" "$(hn_event_meta internet_up)"
assert_eq "catalog: operator_reselected is internet|warning" "internet|warning" "$(hn_event_meta operator_reselected)"
assert_eq "catalog: unknown kind -> empty" "" "$(hn_event_meta no_such_event)"

# ── hn_event_record — the shared recorder ─────────────────────────────────────
export HN_EVENT_LOG="$TMP/events.log"
: > "$HN_EVENT_LOG"

hn_event_record internet_down "PassWall disabled; direct internet (fail-open)" passwall-health
hn_event_record device_joined "New device 96:04:e1 (192.168.1.50)" "96:04:e1:00:00:00"
hn_event_record node_rotated "cdn_ws -> hyst_vps" passwall-health
assert_eq "record: 3 lines appended" "3" "$(wc -l < "$HN_EVENT_LOG" | tr -d ' ')"
assert_eq "record: line has 6 pipe fields" "6" "$(awk -F'|' 'NR==1{print NF}' "$HN_EVENT_LOG")"
assert_eq "record: severity derived, not passed" "critical" "$(awk -F'|' 'NR==1{print $3}' "$HN_EVENT_LOG")"
assert_eq "record: kind stored" "internet_down" "$(awk -F'|' 'NR==1{print $4}' "$HN_EVENT_LOG")"
assert_eq "record: actor stored" "passwall-health" "$(awk -F'|' 'NR==1{print $5}' "$HN_EVENT_LOG")"
assert_eq "record: message stored" "PassWall disabled; direct internet (fail-open)" "$(awk -F'|' 'NR==1{print $6}' "$HN_EVENT_LOG")"
# epoch field parses as a number
assert_eq "record: epoch numeric" "1" "$(awk -F'|' 'NR==1 && $1 ~ /^[0-9]+$/{print 1}' "$HN_EVENT_LOG")"

# Unknown kind is rejected: nothing appended, non-zero exit.
before=$(wc -l < "$HN_EVENT_LOG")
hn_event_record bogus_kind "should not appear" >/dev/null 2>&1 && rejected=no || rejected=yes
assert_eq "record: unknown kind rejected" "yes" "$rejected"
assert_eq "record: rejected line not appended" "$before" "$(wc -l < "$HN_EVENT_LOG" | tr -d ' ')"

# ── hn_event_list — newest-first, optional category filter ───────────────────
export HN_EVENT_TS=1700000000
: > "$HN_EVENT_LOG"
hn_event_record internet_down "down msg" passwall-health
export HN_EVENT_TS=1700000100
hn_event_record device_joined "join msg" "aa:bb"
export HN_EVENT_TS=1700000200
hn_event_record internet_up "up msg" passwall-autorecover

list=$(hn_event_list 10)
assert_eq "list: newest first" "1700000200|internet|info|internet_up|passwall-autorecover|up msg
1700000100|device|info|device_joined|aa:bb|join msg
1700000000|internet|critical|internet_down|passwall-health|down msg" "$list"
assert_eq "list: limit 2" "1700000200|internet|info|internet_up|passwall-autorecover|up msg
1700000100|device|info|device_joined|aa:bb|join msg" "$(hn_event_list 2)"
assert_eq "list: category filter" "1700000200|internet|info|internet_up|passwall-autorecover|up msg
1700000000|internet|critical|internet_down|passwall-health|down msg" "$(hn_event_list 10 internet)"
assert_eq "list: missing log" "" "$(HN_EVENT_LOG="$TMP/absent" hn_event_list 10)"

summary
