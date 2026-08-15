# 10 — Speed-test scheduler + trend + degradation alert

**What to build:** Nightly speed tests on the MCI link, history trend surfaced in the app/bot, and an alert when throughput collapses or drifts below a floor.

**Blocked by:** Ticket 01

**Status:** resolved (speedtest.sh deployed + cron + trend log, verified)

- [ ] /speedtest runs and returns MBps; a simulated throughput drop fires the degradation alert.
