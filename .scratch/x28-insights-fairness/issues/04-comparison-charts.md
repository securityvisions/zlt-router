# 04 — Per-person comparison charts

**What to build:** On the dashboard, next to the existing ledger card, a comparison view: each person's usage as week-over-week and month-over-month line/bar charts, so trends ("parsa is climbing", "weekends spike") are visible at a glance instead of requiring mental math over daily tables. Reads entirely from existing stores (ledger queries + snapshots); alias-aware so a person's series survives device swaps.

**Blocked by:** 01 — Restore point; 02 — MAC alias continuity (series must not fork mid-history).

**Status:** ready-for-agent

- [ ] Week-over-week and month-over-month views per person, rendered from ledger data
- [ ] Alias-resolved persons show one continuous series across device swaps
- [ ] Chart degrades gracefully (empty-state message, not a broken frame) when a range has no data
- [ ] Fixture tests cover the chart-data endpoint contract (shape, ordering, empty month)
- [ ] Deploys via targeted pushes only; proxy engine untouched
