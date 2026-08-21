# 03 — TelemetryStore seam

**What to build:** The two logs (`/etc/telemetry/hourly.log` vs `/data/proxy/usage/telemetry.log` with 2 schemas / 2 prunings) become one `TelemetryStore.append(row: TelemetryRow {ts, LinkState, ProbeSample})` with `prune(8760)` + `qualitySeries(hours)` — `web` `QualityChart` and `Router API` `quality` finally share one history.

**Blocked by:** 01 — LinkState seam, 02 — ProbeService seam

**Status:** resolved

- [x] `TelemetryStore.append(row)` + `prune(8760)` + `qualitySeries(hours)` — versioned schema, single migration from old logs.
- [x] `x28-telemetry.sh` and `x28-thermal-loop.sh` both append via `TelemetryStore`; `hn_quality_series` can parse the single log.
- [x] Web `QualityChart` and `Router API` `quality` share the same `qualitySeries` output.
