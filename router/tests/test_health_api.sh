#!/bin/sh
# Unit tests: Router API /health + /quality — the derived Network Health Score
# (ADR-0005) and the hourly quality-history feed. State wrappers (ra_q_*,
# ra_svc_probe, ra_telemetry_age, ra_dns_stats) are overridden with fixtures
# (same as test_status.sh), so the builders are called directly — run_route's
# subshell cannot inherit function overrides.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
. "$HERE/lib.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
ra_ts() { echo 0; }

# ── /health ───────────────────────────────────────────────────────────────────
# Healthy everything: link OK, proxy up, no services down, fresh telemetry,
# DNS success 99% at 50ms -> score 100, Excellent.
ra_q_latency() { echo 0.3; }
ra_q_passive() { echo 12.0; }
ra_proxy_state() { echo "up|0.31"; }
ra_svc_probe() { echo "dnsmasq=up
nlbwmon=up
uhttpd=up
odhcpd=up
rpcd=up
passwall=up
adblock=up
sqm=up"; }
ra_telemetry_age() { echo 60; }
ra_dns_stats() { echo "forwarded=100
answered=0
retried_failed=1
avg_latency_ms=50
success_rate=0.9900"; }

out=$(ra_json_health)
assert_json_eq "health perfect" '{"score":100,"band":"Excellent","as_of_unix":0,"components":[
  {"name":"link_quality","weight":30,"penalty":0,"detail":"OK"},
  {"name":"proxy","weight":20,"penalty":0,"detail":"up"},
  {"name":"services","weight":20,"penalty":0,"detail":""},
  {"name":"freshness","weight":15,"penalty":0,"detail":"60s"},
  {"name":"dns","weight":15,"penalty":0,"detail":"success=0.9900 latency=50ms"}
]}' "$out"

# Everything degraded -> score 0, Poor.
ra_q_latency() { echo 5.0; }
ra_q_passive() { echo 3.0; }
ra_proxy_state() { echo "down|"; }
ra_svc_probe() { echo "dnsmasq=down
nlbwmon=down
uhttpd=down
odhcpd=down
rpcd=up
passwall=down
adblock=down
sqm=down"; }
ra_telemetry_age() { echo 7200; }
ra_dns_stats() { echo "forwarded=100
answered=0
retried_failed=30
avg_latency_ms=500
success_rate=0.7000"; }

out=$(ra_json_health)
assert_json_eq "health all bad" '{"score":0,"band":"Poor","as_of_unix":0,"components":[
  {"name":"link_quality","weight":30,"penalty":30,"detail":"ALERT|degraded"},
  {"name":"proxy","weight":20,"penalty":20,"detail":"down"},
  {"name":"services","weight":20,"penalty":20,"detail":"dnsmasq,nlbwmon,uhttpd,odhcpd,passwall,adblock,sqm"},
  {"name":"freshness","weight":15,"penalty":15,"detail":"7200s"},
  {"name":"dns","weight":15,"penalty":15,"detail":"success=0.7000 latency=500ms"}
]}' "$out"

# Mixed: link degraded + one service down -> 65, Degraded.
ra_q_latency() { echo 5.0; }
ra_q_passive() { echo 3.0; }
ra_proxy_state() { echo "up|0.31"; }
ra_svc_probe() { echo "dnsmasq=up
nlbwmon=down
uhttpd=up
odhcpd=up
rpcd=up
passwall=up
adblock=up
sqm=up"; }
ra_telemetry_age() { echo 60; }
ra_dns_stats() { echo "forwarded=100
answered=0
retried_failed=0
avg_latency_ms=20
success_rate=1.0000"; }

out=$(ra_json_health)
assert_json_eq "health mixed" '{"score":65,"band":"Degraded","as_of_unix":0,"components":[
  {"name":"link_quality","weight":30,"penalty":30,"detail":"ALERT|degraded"},
  {"name":"proxy","weight":20,"penalty":0,"detail":"up"},
  {"name":"services","weight":20,"penalty":5,"detail":"nlbwmon"},
  {"name":"freshness","weight":15,"penalty":0,"detail":"60s"},
  {"name":"dns","weight":15,"penalty":0,"detail":"success=1.0000 latency=20ms"}
]}' "$out"

# ── /quality ──────────────────────────────────────────────────────────────────
cat > "$TMP/telemetry" <<EOF
2026-08-15 22:00|10.0|5.0|up|0.30|1.19|cdn_ws
2026-08-15 23:00|10.5|5.0|up|0.34|2.01|cdn_ws
2026-08-16 00:00|11.0|5.0|up|0.31|2.55|hyst_vps
EOF
export RA_TELEMETRY_LOG="$TMP/telemetry"

out=$(ra_json_quality 24)
assert_json_eq "quality full" '{"hours":24,"points":[
  {"ts":"2026-08-15 22:00","latency_s":0.30,"passive_mbps":1.19,"node":"cdn_ws"},
  {"ts":"2026-08-15 23:00","latency_s":0.34,"passive_mbps":2.01,"node":"cdn_ws"},
  {"ts":"2026-08-16 00:00","latency_s":0.31,"passive_mbps":2.55,"node":"hyst_vps"}
]}' "$out"

out=$(ra_json_quality 1)
assert_json_eq "quality hours 1" '{"hours":1,"points":[
  {"ts":"2026-08-16 00:00","latency_s":0.31,"passive_mbps":2.55,"node":"hyst_vps"}
]}' "$out"

summary
