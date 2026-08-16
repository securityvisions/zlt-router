# 22 — Quotas + crossing events

**What to build:** Per-person monthly quota with warn and critical thresholds (informational — no enforcement). Crossings are diffed on each poll like the package-LOW event and land in the inbox and the activity timeline.

**Blocked by:** 18 — Room v5→v6 migration spine

**Status:** resolved (QuotaCrossing + per-poll diff + tests)

- [ ] Quota warn→critical crossing diffed per poll.
- [ ] Crossing writes one inbox row and one activity row.
- [ ] Quota progress shows in the person view.
