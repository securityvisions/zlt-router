# 08 — Snapshot + docs promotion

**What to build:** The paper trail and safety net for the batch. Before any of this batch's deployments touch the box, take a fresh rollback snapshot (manifest + restore notes, proven drill). After the batch lands: CONTEXT.md glossary gains the new self-heal terms (Boot doctor, Maintenance window, Drift alert, Bearer bounce), docs reflect the changed failover timings, and the reliability story in README/OPERATIONS matches reality.

**Blocked by:** 01, 02, 03, 04, 05, 06, 07 — snapshot gates first deploy; docs describe what actually shipped.

**Status:** ready-for-agent

- [ ] Rollback snapshot created before this batch's first deploy (manifest verified, restore notes written)
- [ ] CONTEXT.md glossary entries added in house style (with _Avoid:_ lines where applicable)
- [ ] Failover timing documentation updated (watchdog cadence, heal thresholds, escalation ladder order)
- [ ] Full suite + web typecheck green; commits follow house convention
