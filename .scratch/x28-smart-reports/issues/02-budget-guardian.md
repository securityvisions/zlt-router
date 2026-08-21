# 02 — Data Budget Guardian

**What to build:** The household learns *before* the Samantel package dies. Asking the bot for `/budget` returns a Card with package remaining GB (from the balance report cache / Remain counters), observed drain rate, projected month-end cost in Toman, and the projected exhaustion date rendered in Jalali. Beyond the on-demand card, tiered alerts fire proactively on the existing hourly telemetry tick and daily roll: warn (<10 GB left, <7 days left, or projected <14 days), urgent (<3 GB, <3 days, <7 days), exhausted (<0.05 GB) — cooldown-gated so a condition notifies once, with exhausted bypassing the cooldown entirely. No new service loop; no network-path changes.

**Blocked by:** 01 — Jalali module (for the exhaustion date rendering) and the batch snapshot.

**Status:** resolved

- [x] Pure tier-decision function unit-tested at every boundary: warn/urgent/exhausted/OK across GB-left, days-left, and projected-days axes — `hn_budget_tier` in hnlib, 20 tests
- [x] Runner reads the balance report cache through an env-overridable path; fixture test asserts the exact Card lines (GB, drain rate, Toman forecast, Jalali date) — `router/x28/x28-budget.sh` with BALANCE_REPORT/BUDGET_STATE/DATE_CMD overrides
- [x] Alerts emit through the cooldown registry (state file env-overridable); fixture test proves one send per condition and immediate send when exhausted
- [x] Missing/stale balance data degrades to an honest "no data" Card, never a wrong number
- [x] `/budget` replies with the Card; unknown arguments handled safely — bot panel/dialog updated, handler in `x28-bot.sh`
- [x] Deployed via the standard push pattern after the snapshot exists; health gate GREEN before and after; live smoke: `/budget` answers on the device — wired via `x28-telemetry.sh` hourly + `deploy.sh`

## Comments

Tier thresholds: exhausted <0.05, urgent <3/<3/<7, warn <10/<7/<14. Budget check is best-effort on the telemetry tick; exhausted bypasses cooldown.
