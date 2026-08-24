# 01 — Live-today ledger + Jalali result headers

**What to build:** Picking today→today in the ledger day-range shows real bytes immediately instead of 0.0 GB, because the range query falls back to today's live per-device file (attributed on the fly via Owner assignments) when no rolled daily file exists yet. The Jalali month query gets the same fallback so the current month never undercounts today. Results headers show Jalali dates with Gregorian underneath.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [x] New `ledger_day_rows <greg-date>` seam in the ledger aggregation store: emits the rolled daily file if present, else attributes today's live device file through owners.conf
- [x] Jalali month query uses the seam — current-month card includes today's live traffic
- [x] Range CGI uses the seam — today→today returns non-zero bytes while today is still live
- [x] Dashboard day-range results header shows the Jalali equivalent of the chosen Gregorian range
- [x] Fixture tests: rolled-day pass-through, live-today attribution (incl. unassigned fallback), month query including today
