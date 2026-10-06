# Map: Automated Zero-Touch Dual-Router Resilience & Fail-Open

**Effort:** `network-failsafe`  
**Label:** `wayfinder:map`  
**Tracker:** Local Markdown (`.scratch/network-failsafe/issues/`)

## Destination

A hardened, zero-touch network resilience system across VPS (`85.121.124.158`), AX3000T (`192.168.1.1`), and X28 (`192.168.70.1`) where:
1. The VPS S-UI proxy core auto-recovers within 3 seconds under crashes or memory pressure.
2. AX3000T's sing-box automatically selects the fastest healthy node via `urltest`, falling back through `vps-reality`, `hy2`, `cdn-ws`, and `via-x28` without manual API intervention.
3. If all proxy nodes fail for 90 continuous seconds, AX3000T seamlessly fails open (direct domestic routing and clean direct DNS) without rebooting, and restores encrypted proxying within 60 seconds of node recovery.

## Notes

- **Domain:** Network engineering, OpenWrt 25.12.5, Sing-Box 1.13, systemd service hardening, POSIX shell daemon under procd.
- **Reference Docs:** `docs/RESEARCH_FAILSAFE_DNS_PROXY_RESILIENCE.md`, `docs/HOME_NETWORK_COMPLETE_REFERENCE.md`.
- **Constraint:** Zero reboot policy on AX3000T. Zero packet loss on failover transitions. No disruption to local device Wi-Fi/DHCP leases.

## Decisions so far

- [01-vps-systemd-hardening](issues/01-vps-systemd-hardening.md): Unified competing `sui`/`s-ui` units, enabled `Restart=always` (3s delay), `LimitNOFILE=1048576`, and `OOMScoreAdjust=-500`. Auto-recovery verified on live kill.
- [02-ax3000t-singbox-urltest-viax28](issues/02-ax3000t-singbox-urltest-viax28.md): Added `via-x28` mesh backup, configured `auto` URLTest with `interval: 30s`, `tolerance: 50`, `interrupt_exist_connections: true`, and routed through `auto`.
- [03-ax3000t-dnsmasq-dns-resilience](issues/03-ax3000t-dnsmasq-dns-resilience.md): Detoured `dns-proxy` DoH via `auto`, isolating LAN DNS from single-node proxy failures.
- [04-ax3000t-failopen-watchdog](issues/04-ax3000t-failopen-watchdog.md): Deployed `/usr/sbin/proxy-watchdog.sh` under `procd` init `/etc/init.d/proxy-watchdog` (90s fail-open / 60s restore hysteresis, zero reboots).
- [05-end-to-end-verification](issues/05-end-to-end-verification.md): Full 6-tier end-to-end validation passed (SOCKS 204 in 0.82s, direct 204 in 0.41s, DNS split resolution functional, watchdog active).
- [06-anti-flap-tuning](issues/06-anti-flap-tuning.md): Increased urltest tolerance to 150ms and interval to 1m, removed aggressive connection interruption, implemented dual-endpoint probing (Google + Cloudflare), and increased watchdog threshold to 150s (5 fails) to eliminate flapping.

## Frontier & Open Tickets

- [01-vps-systemd-hardening](issues/01-vps-systemd-hardening.md): Harden `sui.service` on VPS with `Restart=always`, high `LimitNOFILE`, and `OOMScoreAdjust=-500`.
- [02-ax3000t-singbox-urltest-viax28](issues/02-ax3000t-singbox-urltest-viax28.md): Configure automated `urltest` failover and add `via-x28` mesh fallback outbound in sing-box on AX3000T.
- [03-ax3000t-dnsmasq-dns-resilience](issues/03-ax3000t-dnsmasq-dns-resilience.md): Configure sing-box DNS timeout dampening (3s) and DoH detour via `auto`.
- [04-ax3000t-failopen-watchdog](issues/04-ax3000t-failopen-watchdog.md): Implement `/usr/sbin/proxy-watchdog.sh` under `procd` with 90s fail-open / 60s restore hysteresis.
- [05-end-to-end-verification](issues/05-end-to-end-verification.md): Verify live failover and recovery across all three failure layers.

## Not yet specified

- Telegram notification on fail-open/restore state transitions via the X28 bot.
- Integration of outage intervals into `/data/proxy/outage-ledger.log` on X28.

## Out of scope

- Re-flashing AX3000T firmware or changing kernel packages.
- Automatic router reboots on network drops (expressly forbidden by ADR).
