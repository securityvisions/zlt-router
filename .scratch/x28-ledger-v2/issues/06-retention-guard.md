# 06 — Retention guard for ledger history

**What to build:** The ledger history stores (daily owner files, rollups, frozen Ledger pages) are explicitly protected from any pruning, and a monthly self-check verifies the history span hasn't shrunk — alerting via Telegram if it has (flash failure, bad rm, restore gone wrong).

**Blocked by:** None — can start immediately.

**Status:** resolved

- [x] Maintenance script's prune paths explicitly whitelist the ledger history stores
- [x] Monthly check: oldest/newest history dates cover the expected span; shrinkage sends a Telegram alert
- [x] Check is idempotent within its period (marker) and safe to run manually
- [x] Fixture test: simulated shrinkage triggers the alert path; healthy span stays silent
