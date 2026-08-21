# 07 — Per-device usage + Toman billing

**What to build:** Per-device usage accounting and Toman cost reporting on
the X28, replacing the AX3000T's nlbwmon billing: a per-MAC accounting
daemon with its database on the persistent volume, baseline/daily-diff
logic, a per-device usage card (GB today + Toman cost at the configured
rates) through the bot, and a weekly bill alert. This is the
highest-risk install of the promotion (a new background package on the
only-WAN device), so it carries a mandatory 24-hour soak with the health
gate green and a proven clean rollback before it closes.

**Blocked by:** 03 — Status collector + Telegram alerts.

**Status:** in-progress

- [ ] The accounting daemon runs as a procd service with its database on
      the persistent data volume (survives reboot).
- [ ] The per-device usage card lists each device with GB used today and
      Toman cost from the configured rate table.
- [ ] The weekly bill alert delivers the aggregated weekly cost on
      schedule.
- [ ] 24-hour soak: proxied path, DNS chain, operator watchdog and load
      all stay healthy; health gate green at the end.
- [ ] Rollback proven: removing the daemon and its service returns the
      X28 to its pre-ticket state with the health gate green.
- [ ] Canonical copies + deploy wiring in the repo.
