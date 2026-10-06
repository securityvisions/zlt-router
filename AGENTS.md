# AGENTS.md

Guidance for coding agents working in this repo.

## Master Documentation

- **First-Step Diagnostics:** For ANY network connectivity, proxy, or DNS diagnostics: NEVER run local host curl/ping tests first. Read [`docs/HOME_NETWORK_COMPLETE_REFERENCE.md`](docs/HOME_NETWORK_COMPLETE_REFERENCE.md) and execute diagnostic probes directly on the AX3000T router (`192.168.1.1`) via SSH.
- **Single Source of Truth:** Read [`docs/HOME_NETWORK_COMPLETE_REFERENCE.md`](docs/HOME_NETWORK_COMPLETE_REFERENCE.md) before diagnosing, configuring, or modifying any system component. It contains the complete architecture, network topology, credential vault, and operational runbook.
- **Resilience Engineering:** Read [`docs/RESEARCH_FAILSAFE_DNS_PROXY_RESILIENCE.md`](docs/RESEARCH_FAILSAFE_DNS_PROXY_RESILIENCE.md) for root-cause analysis of DNS/proxy failover, sing-box URLTest mechanics, and fail-open watchdog specifications.
- **FTTH & Infrastructure Strategy:** Read [`docs/FTTH_DEPLOYMENT_AND_MINIPC_STRATEGY.md`](docs/FTTH_DEPLOYMENT_AND_MINIPC_STRATEGY.md) for the 12-unit residential FTTH deployment plan in Ponak and Mini-PC HomeLab architecture.
- **Shatel vs. Tanoma Comparative Guide:** Read [`docs/SHATEL_FIBER_VS_TCI_TANOMA_DEFINITIVE_GUIDE.md`](docs/SHATEL_FIBER_VS_TCI_TANOMA_DEFINITIVE_GUIDE.md) for the complete 10-vector head-to-head evaluation between Shatel Fiber and TCI Tanoma.
- **Smart TV & IPTV Ecosystem:** Read [`docs/DEVICE_SAMSUNG_Q70C_TIZEN_ECOSYSTEM.md`](docs/DEVICE_SAMSUNG_Q70C_TIZEN_ECOSYSTEM.md) for Samsung Q70C QLED specifications, Developer Mode / SDB access, sideloaded applications inventory, and the router-hosted autonomous IPTV streaming proxy architecture.

## System Topology & Access

The home network is a dual-router cellular and proxy ecosystem with a remote VPS:

1. **Primary House Router — Xiaomi AX3000T (`192.168.1.1`)**:
   - Clean OpenWrt 25.12.5 mainline, dual-core MediaTek MT7981B.
   - Access: `sshpass -p "xirouter123" ssh root@192.168.1.1` (or LuCI on port 80/443).
   - Dedicated Proxy Core: `sing-box` 1.13 (`/etc/sing-box/config.json`, Clash API `:9090`, SOCKS `:1080`).
   - Daemons: `/usr/sbin/wan-detector` (auto-WAN port detection), `/usr/sbin/proxy-watchdog.sh` (autonomous dual-endpoint fail-open watchdog).
   - Transparent Interception: `/etc/axproxy.sh` & `/etc/axproxy.nft`.
   - IPTV Engine: `/www/cgi-bin/tv.m3u8`, `/www/cgi-bin/stream`, `/www/cgi-bin/media` (real-time manifest rewriter & sequence sanitizer).

2. **WAN Cellular Gateway — Tozed ZLT X28 (`192.168.70.1`)**:
   - MediaTek MT6890 5G CPE, OpenWrt 19.07-SNAPSHOT.
   - Access: `sshpass -p "G5K0utrzATYX" ssh -o HostKeyAlgorithms=+ssh-rsa root@192.168.70.1` (or Telnet `nc 192.168.70.1 23`).
   - Uplink: Samantel SIM (MCI 5G NSA PLMN 43211 / Rightel fallback).
   - Control Plane & Scripts: `/data/proxy/` hosts `@xirouterbot` (`x28-bot.sh`), `operator-watchdog.sh`, `mihomo` backup engine (:1080), and telemetry.
   - Bypass: AX3000T IP `192.168.70.2` has `RETURN` in iptables (never double-proxied).

3. **Remote Proxy Origin — VPS (`85.121.124.158`)**:
   - Ubuntu 24.04 LTS.
   - Access: `ssh vps` (using `~/.ssh/id_ed25519_agent`).
   - Service: `s-ui.service` (`/usr/local/s-ui/sui`), hardened with `Restart=always` (3s delay), `LimitNOFILE=1048576`, `OOMScoreAdjust=-500`.
   - Panel: `http://85.121.124.158:2095/app/` (`suiadmin` / `Sui-697ebba6619cf922`).
   - Inbounds: `REALITY-443` (TCP), `HYSTERIA2-31800` (UDP, salamander obfs), `CDN-WS-8443`.

4. **Smart Home & Media — Samsung Q70C QLED TV (`192.168.1.105`)**:
   - 2023 55" 4K QLED (`QA55Q70CAUXZN`), Tizen OS 9.0 (`armv7` 32-bit).
   - Access: SDB port `26101` (`sdb connect 192.168.1.105:26101`), REST API `http://192.168.1.105:8001/api/v2/`.
   - Sideloaded Apps: 21 apps including TizenTube (ad-free YouTube + SponsorBlock), Jellyfin AVPlay, Moonlight (4K PC streaming), Stremio, EN-IPTV_Player, Overscan browser.
   - IPTV Integration: Fed by AX3000T on-demand stream proxy (`http://192.168.1.1/cgi-bin/tv.m3u8`) with real-time 32-bit integer overflow rewriting for Telewebion streams.

## Laptop Hotspot Triage (Crucial for AI Agent Sessions)

When diagnosing a network outage while communicating via mobile hotspot:
- Plugging Ethernet to the laptop triggers Windows DHCP default gateway metric 25 (overriding Wi-Fi metric 45), killing the chat session.
- **Remedy:** In elevated Windows cmd/PowerShell, run:
  ```cmd
  netsh interface ipv4 set interface "Ethernet" metric=9999
  route add 192.168.70.0 mask 255.255.255.0 192.168.1.1 metric 1
  ```
  This preserves hotspot internet for chat while enabling local L2/L3 routing to both `192.168.1.1` and `192.168.70.1`.

## Conventions

- Read `docs/HOME_NETWORK_COMPLETE_REFERENCE.md` and `CONTEXT.md` before doing anything in this repo.
- Check `docs/adr/` for decisions relevant to the area you're touching.
- Issues and specs live under `.scratch/<feature-slug>/` (see `docs/agents/issue-tracker.md`).
- ZERO automatic reboots on AX3000T — resilience is handled via nftables flush and DNS redirection, never via rebooting.
- Operational access credentials and network vault are maintained in `docs/HOME_NETWORK_COMPLETE_REFERENCE.md`.
