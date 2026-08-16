# 23 — Activity timeline + permanent audit

**What to build:** A prunable 180-day activity timeline filtered by person / device / billing / packages / network / alerts, and a permanent audit of billing changes (rate, payment, ownership, edits) that is never pruned. Existing ownership-audit writes move to the audit store.

**Blocked by:** 18 — Room v5→v6 migration spine

**Status:** resolved (activity+audit models + keepers + 180d pruning)

- [ ] Timeline records events and prunes past 180 days.
- [ ] Audit records are permanent; ownership audit moves to the audit store.
- [ ] Timeline filters work for each category.
