# 06 — Extract health model into health-model.sh

**What to build:** Health score computation, link/proxy/service/DNS penalty functions, quality decision/suspicion gate, service-health probe list, and DNS success-rate calculation move from hnlib into `health-model.sh` — the Network Health Score's compute engine (ADR-0005).

**Blocked by:** 04.

**Status:** ready-for-agent

- [ ] health-model.sh exports: hn_health_link_penalty, hn_health_proxy_penalty, hn_health_freshness_penalty, hn_health_score, hn_health_band, hn_svc_probe, hn_svc_down, hn_svc_penalty, hn_dns_success_rate, hn_dns_penalty, hn_dns_stats, hn_q_decision, hn_q_suspicious
- [ ] hnlib re-exports during migration
- [ ] test_health.sh passes unchanged against re-exported functions
- [ ] New test_health_model.sh runs the same assertions against the new module directly
