# 05 — Restore server routing rules and subscriptions

**What to build:** The server-wide routing policy (Iran IPs direct, private IPs and bittorrent blocked) is restored, and the subscription service serves regenerated per-client links; the firewall allows the subscription port and no longer exposes the old panel port.

**Blocked by:** 03, 04

**Status:** ready-for-agent

- [ ] The generated config contains the routing rules: Iran IPs direct, private IPs blocked, bittorrent blocked
- [ ] The subscription service returns a valid per-client config
- [ ] The firewall allows the subscription port and the old panel port is removed
