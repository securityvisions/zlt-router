# 06 — Escalation ladder: node → operator → fail-open

**What to build:** When the whole node chain is degraded, the system escalates to re-selecting the cellular operator (the existing reselect path) *before* resorting to fail-open — and only fails open after the operator rung also fails. Each rung alerts through the cooldown-gated alert path, so the operator sees the network degrade before it drops.

**Blocked by:** 02 — Prefactor: one cooldown helper; 04 — Quality-aware node rotation in the failover chain

**Status:** resolved (escalation ladder node->operator->fail-open; tests)

- [ ] Escalation decision seam (node-state + operator-state → next action), fixture-tested.
- [ ] Operator re-selection triggers only after every node is degraded.
- [ ] Fail-open only after the operator rung fails; an alert fires per rung with cooldown.
- [ ] Deployed and verified live.
