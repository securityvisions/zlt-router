# 02 — Event instrumentation: failover chain

**What to build:** The failover chain records its decisions as Network Events: internet up/down transitions, node rotation, operator re-selection, quality degraded/recovered. A simulated link failure produces `internet_down`, recovery produces `internet_up`, both in the log; node changes record `node_rotated`/`operator_reselected`; quality drops record `quality_degraded`/`quality_recovered` with transition dedup.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] failopen/autorecover record internet up/down at the right transitions.
- [ ] Node rotation and operator re-selection record their events.
- [ ] Quality degraded/recovered fire once per episode (no spam).
