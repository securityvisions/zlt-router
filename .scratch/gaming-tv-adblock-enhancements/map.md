# Tri-Vector Enhancement Map: Gaming DSCP, Samsung TV IPTV & Adblock-Fast

Label: `wayfinder:map`

## Destination

Deploy the tri-vector enhancement suite across AX3000T (`192.168.1.1`) and X28 (`192.168.70.1`):
1. **Gaming Latency (CAKE DSCP & Port Tagging):** Prioritize real-time gaming UDP/TCP packets (Steam/Valve SDR CIDRs, Discord voice, gaming ports) into CAKE SQM's highest priority diffserv class (`CS6` / `EF`) via nftables on AX3000T without deprioritizing bulk house bandwidth.
2. **Samsung Q70C IPTV Prefetch & Control:** Implement lightweight 2-chunk RAM prefetch caching in `/tmp` for sub-second channel switching on Telewebion streams, and integrate TV power/status control into `@xirouterbot` via REST API port 8001 / SDB.
3. **Smart Network Adblock:** Configure `adblock-fast` with curated domestic Persian filters (AdGuard Persian, Yektanet, Tapsell) and an explicit Iranian banking/Shaparak/university whitelist.

## Notes

- Domain: Xiaomi AX3000T OpenWrt 25.12.5, ZLT X28 OpenWrt 19.07, Samsung Q70C Tizen 9.0 (`192.168.1.105`).
- Target devices: AX3000T (`192.168.1.1`), X28 (`192.168.70.1`), TV (`192.168.1.105`).
- Skills to consult: `domain-modeling`, `diagnosing-bugs`.
- Standing preferences: Zero reboots; hot reload only; preserve existing WPA2/WPA3 split SSIDs and sing-box outbounds; verify all tests pass in `router/tests/`.

## Decisions so far

- [01 - Gaming DSCP Tagging & CAKE SQM Priority Queue](issues/01-gaming-dscp-cake-priority.md): Tag Steam SDR prefixes and gaming UDP/TCP ports with DSCP CS6 in nftables postrouting, feeding CAKE Voice priority tin.
- [02 - IPTV Chunk RAM Prefetch Caching for Sub-Second Zapping](issues/02-iptv-ram-prefetch-caching.md): Multi-tiered RAM caching for CDN edge nodes and HLS manifests with asynchronous chunk pre-warming, cutting channel zapping latency on Samsung TV.
- [03 - Samsung Q70C TV Power & Status Control via Telegram Bot](issues/03-samsung-tv-bot-control.md): Bidirectional L3 routing from X28 to AX3000T LAN, TV REST API telemetry, and WOL remote power toggle integrated into @xirouterbot.
- [04 - Adblock-Fast Domestic Persian Filtering & Banking Whitelist](issues/04-adblock-fast-persian-whitelist.md): Curated Iranian adblock list (Yektanet, Tapsell, Sabavision) blocking 6,279 domains with zero-impact banking and university whitelist.

## Not yet specified

<!-- see "Fog of war": in-scope fog you can't ticket yet; graduates as the frontier advances -->

- Dynamic per-device QoS bandwidth throttling toggled via Telegram bot command (`/gamemode on|off`).
- SDB automated app launcher scripts for sideloaded TV apps (TizenTube, Moonlight).
- Long-term adblock DNS query caching stats in NOC dashboard.

## Out of scope

<!-- see "Out of scope": work ruled beyond the destination; closed, never graduates -->

- Full traffic shaping of WAN cellular baseband on X28 MT6890 (handled upstream by MCI radio scheduler).
- Installing heavy Pi-hole / AdGuard Home Docker containers on flash-constrained AX3000T.
