# 18 — Room v5→v6 migration spine

**What to build:** One explicit, tested Room migration to the v2 schema — payments, inbox events, activity events, audit events, automation rules, saved views, and message templates; plus new person columns (credit, quota) and device columns (ip, type, tags, last-seen, analytics exclusion). It seeds synthetic payments from the existing ledger and copies ownership audit into the audit store. Every D-phase ticket builds on this. Requires an Android build environment.

**Blocked by:** None — can start immediately.

**Status:** resolved (Room v5->v6 migration + 19-table schema + migration test)

- [ ] Explicit v5→v6 migration; androidTest against the committed schema snapshots.
- [ ] Synthetic payments seeded from the ledger's `paidToman`; ownership audit migrated; ledger rows preserved.
- [ ] No destructive migration ever touches the ledger.
