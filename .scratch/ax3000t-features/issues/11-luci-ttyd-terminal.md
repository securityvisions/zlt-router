# 11 — In-Browser Web Terminal (luci-app-ttyd + ttyd)

**What to build:** Install `ttyd` and `luci-app-ttyd` on the AX3000T. Embeds a responsive command-line terminal directly inside the LuCI web interface (`Services -> Terminal`), enabling full terminal access from mobile browsers or tablets with root authentication and zero external port exposure.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

## Implementation Details

- Packages: `ttyd` (606 KiB) and `luci-app-ttyd` (4.7 KiB).
- Security:
  - Binds to localhost / LAN only.
  - Requires authenticated LuCI session (root credentials).
  - Protected behind standard OpenWrt session token.
- Access: LuCI Web UI -> Services -> Terminal.

## Verification Criteria

- [ ] `ttyd` and `luci-app-ttyd` installed cleanly via apk.
- [ ] LuCI displays `Services -> Terminal` menu.
- [ ] Opening the terminal in browser provides an interactive bash/ash prompt.
- [ ] Footprint check: ~611 KB flash, <2 MB RAM when active.
