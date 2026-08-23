# 05 — Extract domain rules into ledger-rules.sh

**What to build:** Owner lookup, budget tier decision, bearer-bounce decision, drift classification, outage pairing/totals/duration formatting, and rescue-supervisor decision move from hnlib into `ledger-rules.sh` — the "household rules" module. These functions all answer questions about *the household's state*, unlike calendar math or HTTP parsing which are generic utilities.

**Blocked by:** 04 — proves the hnlib split pattern before tackling the larger rules group.

**Status:** ready-for-agent

- [ ] ledger-rules.sh exports: hn_owner_of, hn_budget_tier, hn_bounce_decide, hn_drift_classify (if present), hn_outage_pair, hn_outage_total, hn_outage_format_duration, hn_rescue_decide
- [ ] hnlib re-exports during migration
- [ ] test_backfill.sh, test_rescue_supervisor.sh, test_outage_ledger.sh pass unchanged
- [ ] New test_ledger_rules.sh consolidates these assertions against the new module
