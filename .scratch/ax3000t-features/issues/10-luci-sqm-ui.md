# 10 — Visual CAKE SQM QoS Web Control (luci-app-sqm)

**What to build:** Install `luci-app-sqm` on the AX3000T. Adds a web interface under `Network -> SQM QoS` in LuCI to monitor CAKE queue status and adjust upload/download shaping speeds (50M/15M) directly from the browser without SSH.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

## Implementation Details

- Package: `luci-app-sqm` (9.4 KiB).
- Integrates with existing `/etc/config/sqm` (`lan4` cake queue).
- Access: LuCI Web UI -> Network -> SQM QoS.

## Verification Criteria

- [ ] `luci-app-sqm` installed cleanly via apk.
- [ ] LuCI displays `Network -> SQM QoS` page.
- [ ] Displays active configuration: `lan4`, `50000` down, `15000` up, `layer_cake.qos`.
- [ ] Footprint check: <10 KB flash, 0 MB added RAM.
