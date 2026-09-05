# 15 — Modern Mobile-Responsive LuCI Theme (luci-theme-material)

**What to build:** Install `luci-theme-material` on the AX3000T. Replaces the dated default Bootstrap theme with a clean, touch-friendly Material Design interface with responsive navigation bars and modern mobile layout.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

## Implementation Details

- Package: `luci-theme-material` (63 KiB).
- Configuration:
  ```sh
  uci set luci.main.mediaurlbase='/luci-static/material'
  uci commit luci
  ```
- Fallback: default Bootstrap theme remains installed in `/luci-static/bootstrap`.

## Verification Criteria

- [ ] `luci-theme-material` installed cleanly.
- [ ] LuCI web admin renders with Material UI design on both desktop and mobile screens.
- [ ] Footprint check: <70 KB flash, 0 MB added RAM.
