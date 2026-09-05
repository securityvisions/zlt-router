# 09 — Visual Per-Device Bandwidth Monitor (luci-app-nlbwmon)

**What to build:** Install `luci-app-nlbwmon` on the AX3000T. Adds an interactive web dashboard under `Status -> Bandwidth Monitor` in LuCI, visualizing real-time and monthly data usage per device (MAC, IP, hostname) with protocol breakdowns and pie charts directly from the running `nlbwmon` daemon.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

## Implementation Details

- Package: `luci-app-nlbwmon` (36 KiB).
- Integrates with existing `/etc/config/nlbwmon` database (`/etc/nlbwmon`).
- Access: LuCI Web UI -> Status -> Bandwidth Monitor.

## Verification Criteria

- [ ] `luci-app-nlbwmon` installed cleanly via apk.
- [ ] LuCI displays `Status -> Bandwidth Monitor` menu page.
- [ ] Interactive charts display per-MAC bandwidth metrics matching active household devices.
- [ ] Memory footprint check: 0 MB added RAM (reads existing nlbwmon DB).
