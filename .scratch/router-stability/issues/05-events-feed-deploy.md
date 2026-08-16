# 05 — Deploy the dashboard event instrumentation (populated events feed)

**What to build:** The dashboard's events feed shows real network events (failover, device lifecycle, proxy, billing) by deploying the instrumented scripts — only once the reboot mechanism is understood and stability is confirmed, so we never add code while the crash question is open.

**Blocked by:** 04

**Status:** pending (gated on 04)

- [ ] Instrumented scripts deployed to the router.
- [ ] `/events` returns live events; the dashboard feed renders them.
