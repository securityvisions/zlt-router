# Architecture

The complete home-network system: **one resilient WAN path, two router tiers, a
VPS proxy origin, and a single control plane** (Telegram bot + Router JSON API +
Xirouter Android app). Everything in this repo — router scripts, the X28 smart
edge, the app, docs, specs/tickets — describes one deployable system.

## Tiers

```
                        Internet
                           │
                  ┌────────▼─────────┐
                  │  VPS 85.121.124.158 │   proxy origin (s-ui / sing-box)
                  │  VLESS+REALITY :443 │   + Hysteria2 :31800, sub :2096
                  └────────┬─────────┘
                           │ REALITY / Hysteria2
              ┌────────────▼──────────────┐
              │  X28 — WAN appliance      │   ← 4G/5G cellular (Samantel SIM, MCI)
              │  · operator stickiness    │
              │  · link telemetry         │
              │  · crypto engine :1080    │   xray-core → VPS (via_x28 node)
              │  · management hardening   │
              └────────────┬──────────────┘
                           │ LAN 192.168.70.1/24
              ┌────────────▼──────────────────┐
              │  AX3000T — the brain         │   ← 192.168.1.1 (WAN 192.168.70.167)
              │  PassWall split routing      │   domestic direct / intl via VPS
              │  DNS split + ad-blocking     │
              │  SQM/CAKE · nlbwmon billing  │
              │  Samantel balance · alerts   │
              │  Telegram bot · Router API   │
              │  Xirouter app (Android)      │
              └──────────────────────────────┘
```

## Role division

| Function | Runs on | Why |
|---|---|---|
| WAN/NAT + hardware offload | **X28** | physical edge; MTK hw_nat active |
| Link stickiness + telemetry | **X28** (script) / AX3000T (watchdog) | only the X28 sees the modem |
| VPN tunnel termination (crypto) | **X28** (crypto engine) and AX3000T (PassWall) | redundancy; X28 has 4× A55 |
| Domestic/international split | **AX3000T** (PassWall, Stage 1) → X28 (Stage 2) | mature stack first |
| DNS split + ad-blocking | **AX3000T** (chinadns-ng + dnsmasq) | mature, RAM-adequate |
| SQM/CAKE | **AX3000T** | proven |
| Usage/billing + balance | **AX3000T** (nlbwmon + Samantel) | existing |
| Control plane (bot/API/app) | **AX3000T** | existing |
| Backup/guest network | **X28** (v2rayA on its LAN) | isolated second net |
| Remote app access | **AX3000T** (cloudflared, planned) | no plain WireGuard in Iran |

## Traffic path

1. Client → AX3000T LAN → PassWall classification:
   - **domestic** → direct (chinadns-ng + ipset/nftset direct lists)
   - **international** → the active node (`cdn_ws` default; `via_x28` switchable
     → routes through the X28 crypto engine → VPS)
2. Fail-open watchdog: on sustained node failure PassWall drops to direct and
   auto-recovers (the planned chain: REALITY → Hysteria2 → via-X28 → direct).

## Control plane

- **Telegram bot** — panel + commands; balance/usage/cost/bill/disk/clients/
  proxy/link alerts; the single surface.
- **Router API** — uhttpd CGI (`/cgi-bin/routerapi.sh/*`), token-gated (HTTP
  Basic), read/write for the same state the bot uses. Contract in `app/API_CONTRACT.md`.
- **Xirouter app** — `app/` (Android, Kotlin): charts, status, balance, usage,
  devices, proxy switch, reboot. LAN-only today; Cloudflare Tunnel is the
  planned remote path.

## Data flows

- **Link telemetry**: X28 vendor API (`linkstate.sh`) → AX3000T
  (`x28link.sh`/`x28watch.sh`) → bot alerts + state files.
- **Usage**: nlbwmon per-MAC → baseline diffs → Toman cost tables (hnlib) →
  bot + API + app.
- **Balance**: Samantel PWA (read-only, cached token) → reports + drain-rate →
  bot tiers + API.
- **Telemetry**: hourly snapshot → `/etc/telemetry/hourly.log` → app charts.

## Resilience layers

1. **Link**: MCI stickiness watchdog (operator drift + RSRP/NR degradation).
2. **Proxy**: PassWall nodes (`cdn_ws`/REALITY/Hysteria2) + `via_x28` tier +
   fail-open → direct + auto-recover.
3. **Management**: hardened X28 mgmt (LAN-only); procd respawn on the crypto
   engine; watchdog-heartbeat supervision on the bot.
4. **Remote**: bot (Telegram) works anywhere; Cloudflare Tunnel planned for the app.

## Repo layout

```
CONTEXT.md / AGENTS.md / docs/ARCHITECTURE.md — vocabulary, agent rules, this doc
docs/          — per-area ops docs (MONITORING_ALERTS, USAGE_BILLING, BALANCE, …)
docs/adr/      — decision records
router/        — canonical router scripts (deployed to the AX3000T)
router/x28/    — X28 smart-edge subsystem (scripts + deploy + templates)
app/           — Xirouter Android app source (merged from ~/router-app)
.scratch/      — local-markdown issue tracker (specs + numbered tickets)
```
