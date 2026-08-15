# 13 — VPS health checks + auto-recovery

**What to build:** The bot monitors the VPS nodes/panel/subscription and alerts on failure; optionally restarts s-ui over SSH; node health is surfaced in the app.

**Blocked by:** None — can start immediately

**Status:** resolved (vpshealth.sh deployed + cron, verified)

- [ ] Stopping s-ui triggers an alert + auto-recovery; health is visible in the app.
