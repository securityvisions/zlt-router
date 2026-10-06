# XI-5G Wi-Fi & Proxy Resilience Map

Label: `wayfinder:map`

## Destination

Eliminate sporadic disconnects and access outages on AX3000T `XI-5G` by disabling conflicting split-SSID `usteerd` band steering, pruning dead outbounds (`hy2`, `cdn-ws`) from sing-box `auto` urltest, setting `interrupt_exist_connections: true`, and hardening sing-box DNS fallback so external DoH never stalls LAN DNS.

## Notes

- Domain: AX3000T (192.168.1.1) Wi-Fi 6 AP, OpenWrt hostapd, usteerd, sing-box 1.13 routing & DNS.
- Target device: Xiaomi AX3000T (`192.168.1.1`).
- Skills to consult: `diagnosing-bugs`, `domain-modeling`, `grilling`.
- Standing preferences: Zero reboots on AX3000T, preserve WPA2/WPA3 mixed on `XI-5G` (`xirouter123`), preserve static IP bindings.

## Decisions so far

- [01 - Disable Conflicting usteerd on Split-SSID Radios](issues/01-disable-conflicting-usteerd.md): Stop and disable usteerd daemon, eliminating split-SSID 802.11v kick storms on XI-5G.
- [02 - Prune Dead Nodes and Harden sing-box urltest](issues/02-prune-dead-nodes-singbox.md): Prune dead nodes (hy2, cdn-ws) from auto, leaving live nodes (vps-reality, via-x28) with interrupt_exist_connections: true.
- [03 - Multi-Resolver Resilience for sing-box DNS](issues/03-singbox-dns-fallback.md): Direct domestic services to ultra-fast local DNS (192.168.70.1) and foreign queries through resilient auto DoH.
- [04 - Dedicated Low-Latency UDP Routing for Gaming & Steam](issues/04-dedicated-gaming-udp-resilience.md): Create dedicated `gaming` urltest group prioritizing Hysteria2 UDP for Valve/Steam SDR CIDRs with seamless TCP reality fallback.

## Not yet specified

- Automated health-test pruning daemon for dead nodes in sing-box config.
- Single unified SSID migration vs explicit split-SSID policy (`XI-5G` / `XI-2G`).

## Out of scope

- Re-flashing AX3000T firmware or altering U-Boot bootloader.
- Modifying remote VPS kernel or s-ui service.
