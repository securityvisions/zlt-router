# 01 — Faster failover tuning

**What to build:** Cut detection latency on the two slowest self-heal paths. The operator watchdog probes every 120 s and needs 3 strikes before switching — ~6 min of dead connectivity per cellular outage becomes ~3 min at a 60 s cadence (same 3-strike threshold, storm guard unchanged). The VPS core-heal loop waits for 10 minutes of a dead auto-group before asking the panel to restart sing-box — that drops to 4 minutes, since the panel restart is cheap and already proven. Both values stay env-overridable; deployed defaults are the new tighter ones.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [ ] Watchdog probe interval default 60 s (env override still honored); log line reflects new interval
- [ ] Core-heal dead-threshold default 4 min (env override honored); action card sent when a restart is triggered
- [ ] Storm guard / cooldown / backoff numbers untouched (no flap risk added)
- [ ] Deployed via the standard push pattern with health gate GREEN before/after; watchdog + heal services restarted and running
- [ ] Live verification: force one failed-probe cycle in dry-run mode and confirm timing matches the new cadence

## Comments

Shipped as defaults (env overrides intact): watchdog interval=60s (startup log verified live), core-heal DEAD_THRESHOLD=4 with Telegram cards on heal/skip/fail. Storm guard untouched. test_alwaysup_defaults.sh pins the constants.
