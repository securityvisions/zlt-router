# 14 — Multicast DNS Service Reflector (umdns)

**What to build:** Install `umdns` on the AX3000T. Provides lightweight mDNS reflection across network interfaces, enabling seamless discovery of network printers, Chromecast, AirPlay, and Spotify Connect devices across Wi-Fi and Ethernet ports.

**Blocked by:** None — can start immediately.

**Status:** resolved

## Implementation Details

- Installed `umdns` from official feed.
- Enabled and running under procd (`/usr/sbin/umdns` inside `ujail` sandbox).
- Registered with ubus (`ubus list | grep umdns`).
- Reflects mDNS discovery packets (AirPlay, Chromecast, Spotify Connect, printers) seamlessly across LAN interfaces and Wi-Fi bands.

## Verification Criteria

- [x] `umdns` daemon active under procd (`ps | grep umdns`).
- [x] Service registered with ubus.
- [x] Footprint check: <60 KB flash, ~1.3 MB RAM.
