# 08 — Quality-history rollup + /quality endpoint

**What to build:** The hourly link-quality samples already in the telemetry log (latency, passive throughput, node) become a chart-ready API: `/quality?hours=N` returns the last N hourly points oldest-first for the dashboard's quality card.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] `hn_quality_series` extracts the quality fields from the telemetry log (tolerant of older rows without them).
- [ ] `/quality?hours=N` returns `{hours, points:[{ts,latency_s,passive_mbps,node}]}`.
- [ ] `test_health_api.sh` green.
