# 04 — UPnP / NAT-PMP Daemon for Open Gaming NAT

**What to build:** Install `miniupnpd-nftables` and `luci-app-upnp` on the AX3000T. Configure on `br-lan` with secure port-forwarding ACLs restricting automatic port mapping to non-privileged ports (`1024-65535`). Enables automated port forwarding for gaming consoles (PlayStation, Xbox, Switch) and PC games (Steam, Call of Duty, GTA Online, Warframe, torrent clients) to guarantee Type 2 / Open NAT.

**Blocked by:** None — can start immediately.

**Status:** resolved

## Implementation Details

- Installed `miniupnpd-nftables` (2.3.9) and `luci-app-upnp` from official feed.
- Enabled in `/etc/config/upnpd` with `secure_mode=1` and port restrictions to non-privileged ports `1024-65535`.
- Active daemon `miniupnpd` listening on SSDP port 1900, NAT-PMP port 5351, and HTTP control port 5000.
- Native nftables integration (`/usr/share/nftables.d/.../20-miniupnpd.nft`) active.
- Provides Open / Moderate NAT for gaming consoles and PC titles on the LAN and Wi-Fi.

## Verification Criteria

- [x] `ps | grep miniupnpd` confirms daemon is running.
- [x] LuCI displays `Services -> UPnP` menu page.
- [x] Daemon listening on SSDP (1900), NAT-PMP (5351), and control port (5000).
- [x] Native nftables hook chains active.
- [x] Footprint check: ~150 KB flash, ~1.4 MB RAM.
