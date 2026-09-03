# 14 — DIRECT-first operating mode (design → ADR)

**What to build:** Today, running fully DIRECT is a fail-open accident that happens when health checks fail. This ticket makes it a deliberate, first-class operating mode: design how "DIRECT-first" coexists with the tunnel modes and the rescue pool — when a household member might choose it (quota emergencies, VPS outages, trust events), how state is visible on dashboard/bot, how entry and exit work safely — and record the decision as an ADR. Deliverable is the written design only; implementation comes later as its own tickets after review.

**Blocked by:** 01 — Restore point.

**Status:** ready-for-agent

- [ ] Design covers: mode states, transitions, safety interlocks with existing watchdog/rescue/fail-open paths, visibility surfaces
- [ ] Explicitly addresses the failure cases observed historically (tunnel death, wedged bearer, config drift)
- [ ] No code shipped in this ticket — outcome is an accepted ADR in the repo's decision record
- [ ] Design reviewed and approved by the household operator before any implementation tickets are cut
