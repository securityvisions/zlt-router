# 06 — Scenario drain forecast

**What to build:** The budget view projects days-left from a single average today. Replace that with three named scenarios — conservative / expected / binge — computed from recent weekday/weekend patterns and holiday flags, each with its own projected exhaustion date, presented with an honest confidence band rather than false precision. Shown on the dashboard budget card and in the bot budget reply; the numbers come from one shared forecast seam both surfaces consume.

**Blocked by:** 01 — Restore point.

**Status:** ready-for-agent

- [ ] Three scenarios computed from existing drain history; expected scenario ≈ today's projection on stable data (continuity check)
- [ ] Confidence band widens visibly when history is sparse or volatile
- [ ] Dashboard card and bot reply show identical numbers (single seam)
- [ ] Forecast math pure + fixture-tested (worked examples, not recomputed expectations)
- [ ] Deploys via targeted pushes only; proxy engine untouched
