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
| Local Media & Download Server | **HomeLab PC** (Pentium G2030 / 10GB DDR3) | Jellyfin, qBittorrent, local storage, proxy crypto offload |
| Workstation & GameStream Host | **Lenovo Legion 5** (Ultra 9 275HX / RTX 5060) | Omarchy Linux dev, network SSH/NOC management, Moonlight 4K120 host |
| Emergency DNS Tunnel (`dnstt-server`) | **VPS 1** (`85.121.124.158`:53 UDP) | Blackout survival tier: Base32 DNS queries over recursive resolvers $\to$ WARP :40000 |
| Emergency DNS Client (`dnstt-client`) | **AX3000T** (`dnstt-emergency` :5300) | Standby procd service (`/etc/init.d/dnstt`) + sing-box socks outbound |
| Mobile Survival Client & MITM Edge | **Redmi Note 9S Curtana** (Android 16, Root) | Magisk `trustusercerts` system CA, PattNG, Briar, dnstt-client-arm64 |

## Traffic path

1. Client → AX3000T LAN → PassWall classification:
   - **domestic** → direct (chinadns-ng + ipset/nftset direct lists)
   - **international** → the active node (`cdn_ws` default; `via_x28` switchable
     → routes through the X28 crypto engine → VPS)
2. Failover and resilience hierarchy:
   - Primary: VLESS+REALITY / CDN-WS
   - Secondary: Hysteria 2 (low-latency gaming & port hopping)
   - Tertiary: X28 Smart Edge crypto engine (`via_x28`)
   - Quaternary: Public rescue pool (collected nodes)
   - **Emergency Blackout Tier: `dnstt-emergency`** (DNS tunneling over UDP 53 via recursive resolvers to VPS 1 `85.121.124.158` when all foreign TCP/non-DNS UDP is severed)
   - Terminal state: Fail-open (direct domestic)
3. Fail-open watchdog: on sustained node failure PassWall drops to direct and
   auto-recovers. The live chain rotates by quality, not just aliveness:
   `cdn_ws → REALITY → Hysteria2 → via_X28 → direct (fail-open)`. The quality
   layer measures latency/throughput through the active node, rotates to a
   healthier fallback when the active node is degraded-but-alive, escalates to
   operator re-selection before fail-open, and auto-failbacks with hysteresis.

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

## Deep Architecture Core Modules (September 2026)

To eliminate code duplication, port drift, and shell fork overhead across both routers, four deep modules form the core service layer:

1. **Device Registry (`router/device-registry.sh`):**
   - Authoritative device identity resolution pipeline.
   - Evaluation order: User override (`/etc/usage-log/user-names`) > DHCP lease (`/tmp/dhcp.leases`) > Cache (`/etc/usage-log/names`) > MAC fallback (`Unknown-XX:XX:XX`).
   - Dynamic path getters enable 100% isolated unit testing.

2. **Proxy Supervisor & State Machine (`router/proxy-supervisor.sh`):**
   - Canonical SOCKS :1080 supervision.
   - Dual-endpoint health probing (Google + Cloudflare HTTP 204).
   - Anti-flap hysteresis: 5 consecutive dual-failures trigger fail-open (nftables flush + domestic DNS `192.168.70.1`), 3 consecutive passes trigger recovery (nftables redirect + `127.0.0.1#5354`).

3. **Unified Billing & Serialization Engine (`router/billing.sh`):**
   - Single source of truth for Iranian Toman accounting, Friday discount rate (`RATE_FRIDAY=4620`), standard rate (`RATE_FULL=7700`), and rounding.
   - Direct dual streaming: text tables for Telegram bot and strict RFC 8259 JSON for the Router API.

4. **Telegram HTML Card Presenter (`router/tg-presenter.sh`):**
   - Deterministic visual presentation engine deployed to both AX3000T and X28.
   - Formats cards, expandable blockquotes, progress bars, monotonic sparklines, temperature badges, and health emojis with zero external dependencies.

## X28 Gateway Subsystem Deep Modules (September 2026 Round 2)

Four deep architectural modules deepen the cellular edge and bridge WAN resilience:

1. **Modem Supervisor & Cellular State Machine (`router/x28/modem-supervisor.sh`):**
   - Canonical AT/telemetry seam: single dispatch of vendor command 401 & 270. Emits RFC 8259 JSON and key=val telemetry (`operator`, `tech`, `signal`, `rsrp`, `rsrp_5g`, `plmn`, `flow`).
   - Anti-flap PLMN state machine: enforces 600s cooldown and storm-guard limit (max 3 switches/hour).
   - Zero-reboot guarantee: recovers cellular service strictly through AT command reselection, never through CPE reboots.

2. **Streaming Rescue Converter & Bulk Engine (`router/x28/rescue-convert.sh`, `router/x28/x28-rescue.sh`):**
   - Zero-fork batch streaming: replaces 300+ subshell process forks in VMess base64 decoding with a single pipeline in `jq`.
   - Single bulk `/proxies` API polling: eliminates N+1 HTTP calls per member node in Mihomo health checks, reducing 30+ HTTP roundtrips to 1 request.

3. **Separated WAN Outage SLA & Household Billing Ledgers (`router/x28/outage-ledger.sh`, `router/x28/billing-ledger.sh`):**
   - Strict domain decoupling: isolated WAN Outage/MTTR/SLA (`epoch|down`, `epoch|up`) from Jalali household billing and Toman rates.
   - `router/ledger-rules.sh` acts as a clean re-export facade with zero recursive sourcing risk.

4. **Idempotent DNS Manager (`router/x28/x28-dns.sh`):**
   - Decouples L7 DNS upstream config from L3/L4 transparent proxy NAT routing.
   - Atomic configuration replacement: compares md5/content before restarting dnsmasq. Automatically purges rogue ISP secondary DNS (`114.114.114.114`). Deletes redundant `dns-fallback.sh`.

## Deep Architecture Core Modules (Round 3 — Comprehensive Deepening)

Four high-leverage architectural deep modules unify fragmented subroutines and eliminate shell friction:

1. **Proxy Watchdog 5-State Machine (`router/proxy-watchdog.sh`):**
   - Unifies fail-open watchdog, dual-endpoint quality probing, operator escalation, and auto-recovery into an explicit 5-state machine (`HEALTHY`, `DEGRADED`, `ROTATING`, `FAILOPEN`, `RECOVERING`).
   - Pure decision test seams (`--next`, `--qrotate`, `--failback`, `--escalate`, `--state`) enabling 100% mock-free unit testing.
   - `passwall-failopen.sh` and `passwall-autorecover.sh` become thin compatibility facades delegating to the unified watchdog.

2. **Telegram Bot Command Dispatcher (`router/x28/bot-dispatch.sh`):**
   - Decouples Telegram network transport (long-poll `getUpdates`, curl, ACK timing) from command parsing, permission gating, and action execution.
   - Dispatches both slash commands and inline keyboard callbacks into structured output registers (`send_html`, `edit_panel`, `send_photo`, `switch_carrier`), eliminating 250+ lines of inline logic from `x28-bot.sh`.

3. **Unified Device Trust Model (`router/device-registry.sh`):**
   - Implements first-class `Device Trust Level` domain model (`Blocked`, `Trusted`, `Known`, `Guest`, `Unknown`).
   - Unifies DHCP lease tracking, devicewatch presence alerts, and quarantine nftables enforcement into one authoritative interface with atomic multi-file persistence.

4. **Structured Router API Pipeline (`router/routerapi.sh`, `router/routerapi_lib.sh`):**
   - Eliminates stdout `@@STATUS:NNN` marker scraping and temporary files in `/tmp`.
   - `ra_handle_request` and `ra_respond` cleanly process requests in-memory and emit RFC-compliant CGI headers and JSON responses directly with zero fork/sed overhead.

## Deep Architecture Core Modules (Round 4 — Full Execution)

Four additional high-leverage architectural modules deepened for testability and zero-downtime operations:

1. **Cellular Gateway & Reselection Seam (`router/x28/modem-supervisor.sh`, `router/x28reselect.sh`, `router/x28link.sh`):**
   - Decoupled AX3000T link stickiness observer (`x28watch.sh`) from X28 modem execution via dedicated client adapters.
   - Dual-path reselection: primary execution via authenticated SSH invocation of `modem-supervisor.sh` (enforcing 600s cooldown and 3/hr storm guard), with automatic fallback to vendor HTTP API (`cmd 228`).
   - Replaced missing `/root/x28reselect.sh` and `/root/x28link.sh` with tested, portable scripts.

2. **Smart TV & IPTV Ingress Gateway (`router/media-gateway.sh`):**
   - Unified Samsung Q70C WOL power management, Tizen OS REST API polling, and Telewebion live edge URL resolution (with 45s TTL caching).
   - Real-time stream rewriter: sanitizes 64-bit `#EXT-X-MEDIA-SEQUENCE` timestamps down to 9 digits to prevent 32-bit integer overflow crashes on Tizen 9.0 AVPlay.
   - Consolidated `/www/cgi-bin/media`, `/www/cgi-bin/stream`, and `/usr/sbin/tv-control.sh` into thin facades over `media-gateway.sh`.

3. **Rescue Subscription & Bulk Node Ingestion (`router/x28/rescue-engine.sh`):**
   - Consolidated candidate node conversion, aliveness querying, and supervision hysteresis.
   - Bulk aliveness evaluation: queries `/proxies` in a single O(1) HTTP call via `jq`, completely eliminating the legacy N+1 loop (`for m in $members; do curl ...`).
   - Pure hysteresis state machine: promotes to rescue pool on >=4 min owned downtime, demotes back after 10 min stable recovery or rescue exhaustion.

4. **Telemetry Aggregation & Network Health Engine (`router/telemetry-engine.sh`):**
   - Declarative 4-subsystem weight matrix calculating composite Network Health Score (0–100):
     - Cellular Link Quality (25 pts): RSRP thresholding & MCI stickiness
     - Proxy / Egress Health (35 pts): Watchdog state & failover status
     - DNS Subsystem Quality (20 pts): Query latency & success rate
     - Compute / Hardware (20 pts): CPU load & RAM utilization
   - Emits structured JSON snapshots and maintains an hourly JSONL rolling ledger (`/etc/telemetry/hourly.jsonl`) pruned to 8760 entries (1 year).

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
