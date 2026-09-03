# 09 — Predictive top-up nudge

**What to build:** Instead of discovering exhaustion after the fact, the system tells you when to buy: combining the scenario forecast with signal-quality trend and drain history, it surfaces a recommendation ("at current patterns, top up around Thursday") in the daily digest and bot, escalating frequency as the date approaches. Purely advisory — it never buys anything and never changes routing.

**Blocked by:** 06 — Scenario drain forecast; 08 — Vendor standing pull.

**Status:** ready-for-agent

- [ ] Recommendation appears in digest + on-demand bot query, consistent with the forecast seam's numbers
- [ ] Escalation cadence ramps near projected exhaustion; silent again after a fresh pack is detected (standing expiry moved)
- [ ] Nudge suppresses itself when forecast confidence is too low (honest uncertainty, no false alarms)
- [ ] Advisory only: no payment execution, no routing changes — asserted in tests
- [ ] Deploys via targeted pushes only; proxy engine untouched
