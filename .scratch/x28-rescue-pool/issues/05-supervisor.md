# 05 — Supervisor: promotion/demotion hysteresis + cards + digest line

**What to build:** Every 60 s: classify owned-group health; promote world→rescue after ~4 min fully-dead (and ≥1 alive rescue node), demote after ~10 min stably-alive; flip via controller selector API. One card per transition; digest gains a rescue-health line. Pure decision function in hnlib, unit-tested.

**Blocked by:** 04.

**Status:** ready-for-agent

- [ ] hn_rescue_decide boundary tests (streaks, enabled flag, rescue-empty, world state)
- [ ] Live hysteresis exercised in dry-run (forced dead-endpoint run shows would-promote)
- [ ] Cards fire exactly once per transition; digest line present
