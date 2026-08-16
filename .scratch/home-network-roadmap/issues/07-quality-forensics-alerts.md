# 07 — Quality forensics + degraded-mode alerts

**What to build:** The hourly telemetry record carries link quality — latency, passive Mbps, and the active node — as trailing fields, and a degraded window fires a *distinct* alert (not the link-down alert) through the cooldown-gated path. The history answers "why was last night slow".

**Blocked by:** 02 — Prefactor: one cooldown helper; 03 — Link-quality measurement module

**Status:** resolved (telemetry trailing quality fields + degraded alerts; live)

- [ ] Hourly telemetry rows gain trailing quality fields; existing `|`-splitting readers still parse.
- [ ] Degraded-mode alert is distinct from link-down and cooldown-gated.
- [ ] Fixture: a degraded window produces the alert.
- [ ] Deployed; telemetry shows per-hour quality.
