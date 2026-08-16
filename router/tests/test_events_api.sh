#!/bin/sh
# Unit tests: Router API /events — the Network Event log feed for the dashboard.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
. "$HERE/lib.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

printf 'TOKEN=t\n' > "$TMP/conf"
export RA_CONF="$TMP/conf"
export HTTP_X_ROUTER_TOKEN=t
export HN_EVENT_LOG="$TMP/events.log"

# Unauthorized -> 401.
out=$(HTTP_X_ROUTER_TOKEN= HTTP_AUTHORIZATION= run_route GET /events "")
assert_eq "events unauth 401" 401 "$(route_status "$out")"

# Empty log -> empty events array.
: > "$HN_EVENT_LOG"
out=$(run_route GET /events "")
assert_json_eq "events empty" '{"events":[]}' "$(route_body "$out")"

# A few events -> newest-first JSON, severity/category/kind/actor/message fields.
export HN_EVENT_TS=1700000000
: > "$HN_EVENT_LOG"
hn_event_record internet_down "PassWall disabled; direct internet (fail-open)" passwall-health
export HN_EVENT_TS=1700000100
hn_event_record device_joined "New device 96:04:e1 (192.168.1.50)" "96:04:e1:00:00:00"
export HN_EVENT_TS=1700000200
hn_event_record internet_up "VPN routing restored" passwall-autorecover
unset HN_EVENT_TS

out=$(run_route GET /events "")
assert_json_eq "events list" '{"events":[
  {"epoch":1700000200,"category":"internet","severity":"info","kind":"internet_up","actor":"passwall-autorecover","message":"VPN routing restored"},
  {"epoch":1700000100,"category":"device","severity":"info","kind":"device_joined","actor":"96:04:e1:00:00:00","message":"New device 96:04:e1 (192.168.1.50)"},
  {"epoch":1700000000,"category":"internet","severity":"critical","kind":"internet_down","actor":"passwall-health","message":"PassWall disabled; direct internet (fail-open)"}
]}' "$(route_body "$out")"

# limit + category filters.
out=$(run_route GET /events "limit=1")
assert_json_eq "events limit 1" '{"events":[
  {"epoch":1700000200,"category":"internet","severity":"info","kind":"internet_up","actor":"passwall-autorecover","message":"VPN routing restored"}
]}' "$(route_body "$out")"

out=$(run_route GET /events "category=internet")
assert_json_eq "events category filter" '{"events":[
  {"epoch":1700000200,"category":"internet","severity":"info","kind":"internet_up","actor":"passwall-autorecover","message":"VPN routing restored"},
  {"epoch":1700000000,"category":"internet","severity":"critical","kind":"internet_down","actor":"passwall-health","message":"PassWall disabled; direct internet (fail-open)"}
]}' "$(route_body "$out")"

summary
