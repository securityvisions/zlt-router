# 04 — UPnP / NAT-PMP Daemon for Open Gaming NAT

**What to build:** Install `miniupnpd-nftables` and `luci-app-upnp` on the AX3000T. Configure on `br-lan` with secure port-forwarding ACLs restricting automatic port mapping to non-privileged ports (`1024-65535`). Enables automated port forwarding for gaming consoles (PlayStation, Xbox, Switch) and PC games (Steam, Call of Duty, GTA Online, Warframe, torrent clients) to guarantee Type 2 / Open NAT.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

## Implementation Details

- Packages: `miniupnpd-nftables` and `luci-app-upnp` from official feed.
- Configuration: `/etc/config/upnpd`:
  ```uci
  config upnpd 'config'
      option enabled '1'
      option enable_natpmp '1'
      option enable_upnp '1'
      option secure_mode '1'
      option internal_iface 'lan'
      option external_iface 'wan'
      option port '5000'
      option download '0'
      option upload '0'

  config perm_rule
      option action 'allow'
      option ext_ports '1024-65535'
      option int_addr '192.168.1.0/24'
      option int_ports '1024-65535'
      option comment 'Allow LAN gaming ports'

  config perm_rule
      option action 'deny'
      option ext_ports '0-65535'
      option int_addr '0.0.0.0/0'
      option int_ports '0-65535'
      option comment 'Deny all other ports'
  ```
- Enable and start via `/etc/init.d/miniupnpd enable && /etc/init.d/miniupnpd start`.

## Verification Criteria

- [ ] `ps | grep miniupnpd` confirms daemon is running.
- [ ] LuCI displays `Services -> UPnP` menu page.
- [ ] Launching a UPnP-capable application or game creates dynamic NAT entry visible in LuCI or `nft list table inet fw4`.
- [ ] Console / game network test reports Open / Moderate NAT status.
- [ ] Footprint check: <200 KB flash, <2 MB RAM.
