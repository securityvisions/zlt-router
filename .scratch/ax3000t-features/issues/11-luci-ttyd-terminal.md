# 11 — In-Browser Web Terminal (luci-app-ttyd + ttyd)

**What to build:** Install `ttyd` and `luci-app-ttyd` on the AX3000T. Embeds a responsive command-line terminal directly inside the LuCI web interface (`Services -> Terminal`), enabling full terminal access from mobile browsers or tablets with root authentication and zero external port exposure.

**Blocked by:** None — can start immediately.

**Status:** resolved

## Implementation Details

- Installed `ttyd` (1.7.7) and `luci-app-ttyd` from official feed.
- Configured to bind on `br-lan` with login authentication.
- Access: LuCI Web UI -> Services -> Terminal.
- Provides interactive shell directly inside desktop and mobile browsers.

## Verification Criteria

- [x] `ttyd` and `luci-app-ttyd` installed cleanly via apk.
- [x] LuCI displays `Services -> Terminal` menu.
- [x] Daemon active under procd (`ps | grep ttyd`).
- [x] Footprint check: ~611 KB flash, <2 MB RAM when active.
