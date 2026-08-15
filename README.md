# home-network

The complete home network system: monitoring, alerting, usage/billing, proxy
resilience, and remote control — spanning two routers, a VPS proxy origin, and
an Android app, all documented and versioned here.

```
X28 (4G/5G WAN appliance) → AX3000T (the brain) → VPS (proxy origin)
                              │
                Telegram bot · Router API · Xirouter app (control plane)
```

## Components

| Piece | What | Where |
|---|---|---|
| **ZLT X28** | cellular WAN edge: MCI link stickiness, link telemetry, xray crypto engine (:1080), management hardening | `router/x28/` |
| **Xiaomi AX3000T** | main router: PassWall split routing, DNS ad-block, SQM/CAKE, nlbwmon billing, Samantel balance, Telegram bot, Router API | `router/` |
| **VPS 85.121.124.158** | s-ui / sing-box proxy origin: VLESS+REALITY :443, Hysteria2 :31800, subscription :2096 | ops doc in `docs/OPERATIONS.md` |
| **Xirouter app** | Android client for the Router API (charts, balance, usage, devices, proxy switch) | `app/` |
| **Control plane** | Telegram bot (@xirouterbot) + Router JSON API + the app | `docs/MONITORING_ALERTS.md`, `app/API_CONTRACT.md` |

The X28 is the single WAN path for the whole house; the AX3000T rides on it and
does the policy/DNS/monitoring work. See `docs/ARCHITECTURE.md` for the full
design and role division.

## Documentation

| Doc | Contents |
|---|---|
| `docs/ARCHITECTURE.md` | the full system architecture (tiers, roles, traffic path, resilience) |
| `CONTEXT.md` | domain glossary (read before working here) |
| `docs/MONITORING_ALERTS.md` | Telegram bot, panel, commands, alert triggers |
| `docs/USAGE_BILLING.md` | per-device usage, Toman cost model, monthly bill |
| `docs/BALANCE.md` | Samantel balance feature incl. realtime depletion monitor |
| `docs/NETWORK_ENHANCEMENTS.md` | DNS ad-blocking, SQM, timezone |
| `docs/OPERATIONS.md` | cron schedule, config files, troubleshooting, rollback |
| `router/x28/README.md` | X28 smart-edge subsystem: deployment, ops, secrets |
| `app/` | Xirouter Android app (source + its own docs) |

## Repo layout & conventions

- `router/` — canonical copies of every script deployed to the routers
  (edit the repo copy, deploy via SSH; never edit on the router directly).
- `router/x28/` — the X28 smart-edge subsystem (scripts, `deploy.sh`, templates).
- `app/` — the Xirouter Android app, merged from `~/router-app`.
- `docs/adr/` — decision records; `.scratch/` — local-markdown issue tracker
  (specs + numbered tickets per feature).
- See `AGENTS.md` for agent guidance.

## Security

No secrets live in this repo. Router credentials (bot token, Samantel password,
SSH passwords, proxy UUID/keys) live only in root-only config files on the
devices (e.g. `/etc/tg.conf`, `/data/proxy/sing-box/xray-proxy.json`). The
`app/` merge excludes signing secrets (`keystore.properties`, `*.jks`).
