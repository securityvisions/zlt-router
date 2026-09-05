# 09 — Visual Per-Device Bandwidth Monitor (luci-app-nlbwmon)

**What to build:** Install `luci-app-nlbwmon` on the AX3000T. Adds an interactive web dashboard under `Status -> Bandwidth Monitor` in LuCI, visualizing real-time and monthly data usage per device (MAC, IP, hostname) with protocol breakdowns and pie charts directly from the running `nlbwmon` daemon.

**Blocked by:** None — can start immediately.

**Status:** resolved

## Implementation Details

- Installed `luci-app-nlbwmon` and `luci-lib-chartjs` from official feed.
- Integrates with running `nlbwmon` database (`/etc/nlbwmon`).
- Access: LuCI Web UI -> Status -> Bandwidth Monitor.
- Displays live per-MAC download/upload graphs, pie charts, and monthly usage.

## Verification Criteria

- [x] `luci-app-nlbwmon` installed cleanly via apk.
- [x] LuCI displays `Status -> Bandwidth Monitor` menu page.
- [x] Interactive charts display per-MAC bandwidth metrics.
- [x] Memory footprint check: 0 MB added RAM.
