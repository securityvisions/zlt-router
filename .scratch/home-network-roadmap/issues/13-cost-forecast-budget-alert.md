# 13 — Cost forecast + pre-bill budget alert

**What to build:** The bot/API projects month-end cost from the usage log and the billing rates (7,700 T/GB full, 4,620 T/GB Friday) and alerts when the projection crosses a threshold, so the bill is never a surprise.

**Blocked by:** None — can start immediately.

**Status:** resolved (forecast.sh + budget alert + tests; cron 07:30)

- [ ] Burn-rate projection is a pure function, fixture-tested, with the Friday rate applied correctly.
- [ ] Budget-crossing alert is cooldown-gated via the shared alert path.
- [ ] Verifiable live through the bot.
