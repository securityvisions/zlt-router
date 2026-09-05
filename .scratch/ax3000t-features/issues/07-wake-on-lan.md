# 07 — Remote Wake-on-LAN Web Control

**What to build:** Install `etherwake` and `luci-app-wol` on the AX3000T. Adds a LuCI web dashboard page under `Services -> Wake on LAN` allowing one-click waking of sleeping PCs, workstations, or home servers over Ethernet using magic packets.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

## Implementation Details

- Packages: `etherwake` and `luci-app-wol` from official feed.
- Configuration: `/etc/config/wol`:
  - Target interface: `br-lan`.
  - Add preset entries for known wired devices (e.g. `parsavisions` PC MAC).
- Access: LuCI Web UI -> Services -> Wake on LAN.

## Verification Criteria

- [ ] `which etherwake` returns `/usr/bin/etherwake`.
- [ ] LuCI displays `Services -> Wake on LAN` interface.
- [ ] Known hostnames/MACs populated from `/tmp/dhcp.leases` in dropdown.
- [ ] Triggering WOL sends broadcast packet on `br-lan` and wakes target PC from sleep.
- [ ] Footprint check: <50 KB flash, 0 MB background RAM (no persistent daemon).
