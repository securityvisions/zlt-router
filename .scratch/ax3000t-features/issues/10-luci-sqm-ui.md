# 10 — Visual CAKE SQM QoS Web Control (luci-app-sqm)

**What to build:** Install `luci-app-sqm` on the AX3000T. Adds a web interface under `Network -> SQM QoS` in LuCI to monitor CAKE queue status and adjust upload/download shaping speeds (50M/15M) directly from the browser without SSH.

**Blocked by:** None — can start immediately.

**Status:** resolved

## Implementation Details

- Installed `luci-app-sqm` and kernel schedulers (`kmod-sched-cake`, `kmod-ifb`) from official feed.
- Integrates with `/etc/config/sqm` (`lan4` cake queue, 50M/15M).
- Access: LuCI Web UI -> Network -> SQM QoS.
- Allows viewing bufferbloat queue stats and tuning bandwidth sliders from the browser.

## Verification Criteria

- [x] `luci-app-sqm` installed cleanly via apk.
- [x] LuCI displays `Network -> SQM QoS` page.
- [x] Displays active configuration: `lan4`, `50000` down, `15000` up, `layer_cake.qos`.
- [x] Footprint check: <10 KB flash, 0 MB added RAM.
