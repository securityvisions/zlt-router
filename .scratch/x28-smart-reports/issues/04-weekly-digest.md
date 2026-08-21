# 04 — Weekly Digest Card

**What to build:** The Friday ~20:00 Telegram send stops being a bare usage/bill table and becomes one full Card — the week's story at a glance: GB used + Toman, top devices, outage minutes that week (from the Outage Ledger), package remaining + projected exhaustion, and current Link quality (RSRP/operator) + uptime. It replaces the existing weekly bill send inside the daily roll while keeping the week-marker once-only gating. A `/digest` command produces the identical Card on demand any day.

**Blocked by:** 02 — Budget Guardian (remaining-GB/exhaustion section), 03 — Outage Ledger (outage minutes section).

**Status:** resolved

- [x] Composer reads all inputs through env-overridable paths; fixture test asserts every section appears with correct numbers (GB summed across day-files, Toman at full/Friday rates, outage minutes from a fixture ledger) — `x28-digest.sh` with USAGE_DIR/HN_OUTAGE_LEDGER/BALANCE_REPORT env, 5 tests
- [x] Friday send replaced in the daily roll; two rolls on the same Friday still produce exactly one digest (week-marker preserved) — `usage-collect.sh` roll now calls `x28-digest.sh` with fallback
- [x] `/digest` on any day renders the identical Card — bot `/digest` and panel:digest
- [x] Missing sources degrade gracefully (no ledger rows yet → zero/n-a line, never an error or empty message)
- [x] Deployed via the standard pattern; live smoke: one manual roll run sends exactly one digest Card; health gate GREEN after

## Comments

Card combines `x28-usage.sh week`, budget card line, outage week total, link state, and week range. Future month-end people report piggybacks the same Friday marker.
