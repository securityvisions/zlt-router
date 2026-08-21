# 02 — Wonderful Status/Link/Dashboard card

**What to build:** `Dashboard card` becomes live and beautiful — `Link` RSRP `▰▱` bar + `temp_badge` 🟢🟠🔴, `Data` gauge `▰▰▰▱▱ 78%` + `Trend ▂▃▅▇` sparkline from `Telemetry log`, `Proxy` + `Devices` + `Disk` rows aligned via `pad`. `/status` and `/link` both render through the same Card.

**Blocked by:** 01 — Panel framework + beautiful Card seam

**Status:** resolved

- [x] `Dashboard card` shows `Data` gauge + `Proxy` + `Devices` + `Disk` + `Load` + `temp_badge`, with `Trend` sparkline from `Telemetry log` when history exists.
- [x] `Link` card shows `RSRP` bar + `tech` + `band` + `flow` + `temp_badge`.
- [x] Both cards share the `Panel` keyboard beneath them.
