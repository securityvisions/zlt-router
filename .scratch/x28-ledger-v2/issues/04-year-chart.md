# 04 — Year chart from rollups

**What to build:** The ledger "year" button renders a 12-bar chart (one bar per Jalali month, Persian month labels) plus per-person yearly totals, reading the 12 rollup files instead of walking every daily file. Replaces the prompt()-driven HTML dump.

**Blocked by:** 02 — Monthly rollups at day-roll (needs the rollup store).

**Status:** resolved

- [x] New year endpoint returns per-Jalali-month per-person GB for a given Jalali year from rollups (fast: ≤12 small files)
- [x] Dashboard renders the 12-bar chart with Persian month labels and a per-person totals row
- [x] Year picker no longer uses a browser prompt; empty years render a friendly empty state
- [x] Fixture test: year endpoint aggregates fixture rollups correctly
