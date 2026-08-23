# 02 — Budget cache refresh loop (always-fresh balance data)

**What to build:** A lightweight procd timer that runs `balance.sh --report` every 15 minutes to keep the balance report cache fresh. This eliminates the class of bugs where budget.json shows blank after a reboot or cache loss, because the cache is continuously refreshed in the background.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [ ] Procd service runs balance.sh --report every 15 minutes (age-gated, not cron)
- [ ] If balance.sh fails, previous cache preserved (guarded cache_report already handles this)
- [ ] Budget hero widget and budget card always show current data after first refresh cycle
- [ ] Deployed on X28; budget.json verified non-empty after cache-clear + 15-minute wait
