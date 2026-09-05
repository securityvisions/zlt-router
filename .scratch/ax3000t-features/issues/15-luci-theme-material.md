# 15 — Modern Mobile-Responsive LuCI Theme (luci-theme-material)

**What to build:** Install `luci-theme-material` on the AX3000T. Replaces the dated default Bootstrap theme with a clean, touch-friendly Material Design interface with responsive navigation bars and modern mobile layout.

**Blocked by:** None — can start immediately.

**Status:** resolved

## Implementation Details

- Installed `luci-theme-material` from official feed.
- Set as default theme: `uci set luci.main.mediaurlbase='/luci-static/material'; uci commit luci`.
- Modern responsive layout renders on mobile and desktop browsers.

## Verification Criteria

- [x] `luci-theme-material` installed cleanly.
- [x] LuCI web admin renders with Material UI design on both desktop and mobile screens.
- [x] Fast page load (<0.1s response time).
- [x] Footprint check: <70 KB flash, 0 MB added RAM.
