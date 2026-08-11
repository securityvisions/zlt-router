#!/bin/sh
# Unit tests: /status JSON — system + disk + proxy state.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
. "$HERE/lib.sh"

ra_load()      { echo "0.10"; }
ra_mem()       { echo "412 944"; }
ra_temp_c()    { echo "48"; }
ra_disk()      { echo "68|3.1G"; }
ra_uptime()    { echo "3 days, 4:12"; }
ra_proxy_state() { echo "up|0.31"; }
ra_proxy_node()  { echo "REALITY-443-parsa"; }

out=$(ra_json_status)
assert_json_eq "status full" '{"uptime":"3 days, 4:12","load":"0.10","ram":{"used_mb":412,"total_mb":944},"temp_c":48,"disk":{"pct":68,"free":"3.1G"},"proxy":{"state":"up","latency_s":0.31,"node":"REALITY-443-parsa"}}' "$out"

ra_proxy_state() { echo "down|"; }
out=$(ra_json_status)
assert_json_eq "proxy down" '{"uptime":"3 days, 4:12","load":"0.10","ram":{"used_mb":412,"total_mb":944},"temp_c":48,"disk":{"pct":68,"free":"3.1G"},"proxy":{"state":"down","latency_s":0,"node":"REALITY-443-parsa"}}' "$out"

summary
