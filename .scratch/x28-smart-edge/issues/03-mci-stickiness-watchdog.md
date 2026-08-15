# 03 — MCI stickiness watchdog

**What to build:** A watchdog (cron */5 on the AX3000T) that alerts via the bot and auto re-selects MCI when the X28 drifts to a weak operator, and alerts on signal/RSRP degradation (LTE anchor or 5G NR). Pure decision function is fixture-testable.

**Blocked by:** Ticket 01

**Status:** resolved (commit 330c6a8 + follow-up)

- [ ] Forcing a drift to a non-MCI operator triggers a bot alert + an automatic re-select to MCI; 9 decision assertions green.
