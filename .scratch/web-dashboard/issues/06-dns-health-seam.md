# 06 — DNS health seam

**What to build:** Reads dnsmasq's internal counters (SIGUSR1 dump): queries forwarded vs answered locally, per-server retried/failed, average query time. Derives a success rate + latency summary via `hn_dns_stats`; a `dns-stats.sh` script captures the live dump from logread. Feeds the health score's DNS component; `dns_unhealthy` events when health drops.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] `hn_dns_stats` parses the SIGUSR1 text into forwarded/answered/retried_failed/avg_latency_ms/success_rate.
- [ ] `hn_dns_penalty` is 0..15 (success<98% → 15, latency>200ms → +8, capped).
- [ ] `dns-stats.sh` captures the live dump; `test_health.sh` green.
