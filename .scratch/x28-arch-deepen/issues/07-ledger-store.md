# 07 — Concentrate Ledger aggregation into ledger-store.sh

**What to build:** The Jalali day-walk, rate-table loading, Toman formatting, empty-month handling, and owners-d aggregation logic currently duplicated across x28-people.sh, x28-budget.sh, x28-digest.sh, and x28-outage-ledger.sh concentrate into a single `ledger-store.sh` module with a narrow interface: `ledger_query(jalali_month) → TSV rows`, `ledger_freeze(month, path)`, `ledger_list()`, `ledger_rates()`. Four consumers become thin callers.

**Blocked by:** 05 — needs ledger-rules for the rate/budget logic that lives alongside the aggregation.

**Status:** ready-for-agent

- [ ] ledger-store.sh exports query/freeze/list/rates
- [ ] people/budget/digest/outage scripts each lose their private walkers/aggregators
- [ ] Fixture-month tests run once at the store seam instead of per-consumer
- [ ] All consumer outputs byte-identical before/after (golden regression)
