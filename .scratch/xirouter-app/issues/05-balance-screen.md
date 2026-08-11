# 05 — Balance screen

**What to build:** The router Balance endpoint (parsed from the cached report: percent, remaining, quota, expiry, drain, series) and the app's Balance screen with a gauge, main-package line and drain projection — the same balance the bot's 📦 Balance card shows.

**Blocked by:** 01, 02

**Status:** ready-for-agent

- [ ] /balance parses the cached report into the documented JSON
- [ ] App Balance screen shows gauge, main plan, expiry and drain
- [ ] No-cache case returns cached:false gracefully
