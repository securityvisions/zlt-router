# 02 — Prefactor: one cooldown helper

**What to build:** The alert-cooldown pattern (state file, `alert <ts>` note, elapsed-time check) exists in three scripts today. The quality-alert tickets (06, 07, 13, 17) would add a fourth copy. Collapse it into one shared helper so all future alerting builds on a single tested implementation instead of duplicating it.

**Blocked by:** None — can start immediately.

**Status:** resolved (hn_cooldown shared; 3 scripts use it)

- [ ] One shared cooldown helper (check + note) in the shared module.
- [ ] The three existing alert scripts use it; their test suites stay green.
- [ ] No behavior change to existing alert timing.
