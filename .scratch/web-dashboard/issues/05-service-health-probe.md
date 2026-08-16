# 05 — Service-health probe

**What to build:** The router answers "which subsystems are healthy": each probe-able service (DNS, bandwidth accounting, web/API, DHCP, proxy core, ad-block, SQM) reports up/down via init-service state or a process probe. The probe is command-backed and overridable; a stopped service reports down without crashing the probe. Feeds the health score's service component.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] `hn_svc_probe` emits `name=up|down` lines; `hn_svc_down` lists the down set; `hn_svc_penalty` is 5/service capped at 20.
- [ ] The probe function is the test seam (overridable).
- [ ] `test_health.sh` green.
