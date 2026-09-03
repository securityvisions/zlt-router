# 05 — 7-day health score chart

**What to build:** The dashboard shows a single instantaneous health verdict today. Add a rolling 7-day health-score chart so the family sees the network's actual track record — dips during operator loss, recoveries after watchdog action — instead of one number that's green right now. Builds on the existing health-gate scoring and telemetry store; if history isn't retained yet, this ticket adds bounded sampling of it.

**Blocked by:** 01 — Restore point.

**Status:** ready-for-agent

- [ ] Health samples retained ≥7 days with bounded storage (rotation, size-capped like the intraday buckets)
- [ ] Dashboard renders a 7-day score trend; current verdict still shown alongside
- [ ] Gaps (device off, missed samples) render as gaps, not fake zeros
- [ ] Contract fixture-tested (sample shape, gap handling)
- [ ] Deploys via targeted pushes only; proxy engine untouched
