# 07 — One ledger seam: Ledger card shows real month data

**What to build:** The household Ledger has one aggregation store but three consumers resolve it through three different lookup chains — and the dashboard snapshot generator's chain points at a path that doesn't exist on the device, so `/api/ledger.json` silently writes `[]` and the Ledger card renders empty while the bot `/people` report (different chain) shows real numbers. Unify resolution on the single canonical location of the ledger store (the same seam the bot and CGI range/year endpoints already succeed through), then verify end-to-end.

End-to-end outcome: opening the dashboard shows per-person current-month usage and Toman cost that match the bot `/people` monthly report exactly; the year/range CGI views keep working; a missing store degrades loudly (visible error state), never as a quiet empty card.

**Blocked by:** 06 — Deploy pipeline owns the dashboard + ledger stack (store must exist at its canonical path first).

**Status:** resolved

- [x] Snapshot generator resolves the ledger store via the same single canonical chain as bot + CGI consumers
- [x] `/api/ledger.json` returns per-person rows (person | bytes | cost_toman) for the live Jalali month
- [x] Dashboard Ledger card totals match bot `/people` monthly report for the same month
- [x] Missing/broken store produces a visible error indicator, not an empty card

## Answer

snap_ledger resolves the store through one chain (env `LEDGER_STORE` > beside-script > `/data/proxy/ledger-store.sh` > legacy usage/ path) and emits loud error objects (`{"error":"ledger store unavailable"}` / `"jalali date unavailable"`), which the card already renders red. Live: `/api/ledger.json` returns real rows matching the bot `/people` card exactly (parsa 7.26 GB · 55931 T, unassigned 4004 T, maman 729 T, baba 114 T). New seams covered by tests/test_dash_ledger.sh (11 assertions).
