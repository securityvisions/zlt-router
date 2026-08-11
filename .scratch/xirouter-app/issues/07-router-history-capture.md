# 07 — Router history capture

**What to build:** An hourly snapshot job (total GB, balance, proxy state) appending to a tiny telemetry log, plus a History endpoint returning the series for the app's charts. Runs in parallel with 02–06.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] Hourly cron appends ts|total_gb|balance_gb|proxy_state
- [ ] /history?kind=usage returns the hourly series with the days window
- [ ] /history?kind=balance returns the daily balance series
