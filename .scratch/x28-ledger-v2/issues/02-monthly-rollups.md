# 02 — Monthly rollups at day-roll

**What to build:** Every midnight day-roll regenerates the current Jalali month's rollup file (date|person|bytes|cost rows, Friday rates applied) from that month's daily owner files — self-healing and idempotent by full-month recompute, no markers. Existing history is backfilled once. The rollup store becomes the fast data source for year views and the compact artifact for backups.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [x] Day-roll writes rollups/<jalali-year-month>.tsv covering that whole Jalali month from owners-d files
- [x] Rows are date|person|bytes|cost with Friday/holiday rate applied per date
- [x] Re-running the roll for the same day produces byte-identical output (idempotent)
- [x] One-shot backfill command generates rollups for all existing history
- [x] Fixture test: rollup content matches an independent manual walk of the fixture owners-d files
