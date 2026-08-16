# 04 — Event instrumentation: proxy + billing + infrastructure

**What to build:** Proxy switches record `proxy_changed`; the budget-forecast crossing records `package_threshold`; API-triggered reboots record `router_rebooted` (before reboot so it persists); the DNS health seam records `dns_unhealthy` when detected.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] `/proxy/switch` records `proxy_changed`.
- [ ] forecast budget alert records `package_threshold`.
- [ ] `/reboot` records `router_rebooted` before rebooting.
