# 07 — Hourly usage heatmap

**What to build:** The "usage weather-map": a dashboard heatmap of household activity by hour (rows = recent days, columns = hours, color = intensity), fed by the intraday buckets. At a glance the family sees when the network actually gets used — evening peaks, quiet mornings, weekend shifts — turning abstract GB numbers into a pattern anyone can read.

**Blocked by:** 03 — Intraday hourly buckets.

**Status:** ready-for-agent

- [ ] Heatmap renders from bucket data; at least one full day of real data visible end-to-end
- [ ] Intensity legend in plain language (quiet / normal / heavy), not raw bytes-only
- [ ] Handles missing hours/days as empty cells, never as zero-usage
- [ ] Renders acceptably on mobile widths
- [ ] Deploys via targeted pushes only; proxy engine untouched
