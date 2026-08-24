# 03 — CSV export for any date range

**What to build:** An "export" button next to the ledger range query downloads the currently selected date range as a CSV file (person, GB, Toman rows) via a format parameter on the range endpoint.

**Blocked by:** 01 — Live-today ledger + Jalali result headers (both edit the range endpoint; sequence to avoid conflicts).

**Status:** resolved

- [x] Range endpoint accepts a format parameter; CSV variant returns text/csv with per-person rows (person, GB, cost)
- [x] CSV includes today's live rows when the range covers today
- [x] Dashboard shows an export control that downloads the current range query as a file
- [x] Fixture test: CSV output for a known range matches expected rows
