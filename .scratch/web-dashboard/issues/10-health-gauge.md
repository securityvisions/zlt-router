# 10 — Dashboard: health gauge + status strip

**What to build:** The dashboard's hero: the Network Health Score as a band-colored radial gauge (Excellent/Good/Degraded/Poor) with the per-component penalty breakdown beneath, plus the quick status strip (proxy state, RAM, temp, disk, uptime) from `/status`.

**Blocked by:** 07, 09

**Status:** ready-for-agent

- [ ] HealthGauge renders score + band + per-component penalties from `/health`, band-colored.
- [ ] StatusStrip renders proxy/ram/temp/disk/uptime from `/status` with ok/down dots.
- [ ] Component tests green (`web/npm test`).
