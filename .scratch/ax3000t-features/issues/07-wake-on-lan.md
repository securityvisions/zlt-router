# 07 — Remote Wake-on-LAN Web Control

**What to build:** Install `etherwake` and `luci-app-wol` on the AX3000T. Adds a LuCI web dashboard page under `Services -> Wake on LAN` allowing one-click waking of sleeping PCs, workstations, or home servers over Ethernet using magic packets.

**Blocked by:** None — can start immediately.

**Status:** resolved

## Implementation Details

- Installed `etherwake` (1.09) and `luci-app-wol` from official feed.
- Configured `/etc/config/wol` to target `br-lan`.
- Verified `etherwake -D -i br-lan <mac>` constructs and broadcasts standard magic packets on the LAN bridge.
- LuCI management page available under `Services -> Wake on LAN`.

## Verification Criteria

- [x] `which etherwake` returns `/usr/bin/etherwake`.
- [x] LuCI displays `Services -> Wake on LAN` interface.
- [x] Triggering WOL sends broadcast packet on `br-lan`.
- [x] Footprint check: <50 KB flash, 0 MB background RAM (no persistent daemon).
