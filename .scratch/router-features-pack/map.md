# Map: High-Value Performance, Wireless & Monitoring Features Pack

**Effort:** `router-features-pack`  
**Label:** `wayfinder:map`  
**Tracker:** Local Markdown (`.scratch/router-features-pack/issues/`)

## Destination

Deploy and verify high-value zero-overhead enhancements on the Xiaomi AX3000T (`192.168.1.1`):
1. **Zero-Byte Tweaks:** Activate `usteer` for automated 5GHz Wi-Fi 6 steering, tune CAKE SQM with `diffserv4` and `ack-filter` for lowest gaming/voice latency under load, and upgrade MiniUPnP to IGDv2 for Open NAT.
2. **Lightweight Monitoring & Control:** Install `darkstat` for per-device real-time traffic graphs on port `:667` (<100KB footprint) and `luci-app-wol` for web Wake-on-LAN.

## Notes

- **Target:** Xiaomi AX3000T (OpenWrt 25.12.5, apk-tools).
- **Constraints:** Total flash budget <500 KiB. Zero disruption to active DHCP leases and Wi-Fi credentials. Zero automatic reboots.

## Decisions so far

- [01-activate-usteer-band-steering](issues/01-activate-usteer-band-steering.md): Activated pre-installed `usteerd` daemon on AX3000T (<1.5MB RAM); verified live steering of dual-band clients to 5GHz Wi-Fi 6 (`hostapd.phy1-ap0`).
- [02-tune-cake-sqm-gaming](issues/02-tune-cake-sqm-gaming.md): Enabled CAKE SQM on WAN (`lan4`) with 4-tin QoS (`diffserv4`) and `ack-filter` (95M down / 25M up); gaming/voice packets isolated into priority tin.
- [03-tune-miniupnp-open-nat](issues/03-tune-miniupnp-open-nat.md): Upgraded MiniUPnP to IGDv2 and removed legacy 1Mbps constraints; enabled Open NAT for PS5/Xbox/PC.
- [04-install-darkstat-monitor](issues/04-install-darkstat-monitor.md): Installed `darkstat` (<150KB flash); live per-device bandwidth graphs running on `http://192.168.1.1:667/`.
- [05-install-luci-app-wol](issues/05-install-luci-app-wol.md): Verified active `luci-app-wol` in LuCI (Services -> Wake on LAN) pre-populated with `WIN10-PC` and `parsavisions-lan`. Zero overhead.

## Frontier & Open Tickets

- [01-activate-usteer-band-steering](issues/01-activate-usteer-band-steering.md): Enable and configure usteer for smart 5GHz band steering.
- [02-tune-cake-sqm-gaming](issues/02-tune-cake-sqm-gaming.md): Enable diffserv4 and ack-filter on active WAN port CAKE SQM.
- [03-tune-miniupnp-open-nat](issues/03-tune-miniupnp-open-nat.md): Upgrade MiniUPnP to IGDv2 and remove 1Mbps rate limits.
- [04-install-darkstat-monitor](issues/04-install-darkstat-monitor.md): Install darkstat and configure web dashboard on port :667.
- [05-install-luci-app-wol](issues/05-install-luci-app-wol.md): Install luci-app-wol for one-click Wake-on-LAN in LuCI.

## Not yet specified

- Local WireGuard tunnel to VPS for external CGNAT traversal (Option 3 from research, deferred).

## Out of scope

- Installing heavy Go/Python applications (Tailscale, CrowdSec, Netdata).
- Modifying Telegram bot scripts or adding Telegram alert handlers.
