# 14 — Multicast DNS Service Reflector (umdns)

**What to build:** Install `umdns` on the AX3000T. Provides lightweight mDNS reflection across network interfaces, enabling seamless discovery of network printers, Chromecast, AirPlay, and Spotify Connect devices across Wi-Fi and Ethernet ports.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

## Implementation Details

- Package: `umdns` (52 KiB).
- Configuration: `/etc/config/umdns`:
  - Interfaces: `lan`
  - Auto-start on boot via procd.

## Verification Criteria

- [ ] `umdns` daemon active under procd (`ps | grep umdns`).
- [ ] Network devices (printers, streaming cast targets) discoverable without manual IP configuration.
- [ ] Footprint check: <60 KB flash, <1 MB RAM.
