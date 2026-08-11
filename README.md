# home-network

Monitoring, alerting, usage/billing, and network enhancements for the home network — all running on a **Xiaomi Mi Router AX3000T** (OpenWrt 25.12.5, `192.168.1.1`).

The system lives on the router (shell scripts + cron). This repo documents it: what's deployed, how it works, and how to operate/troubleshoot it.

## System overview

- **Telegram bot (@xirouterbot)** — interactive button panel + text commands; the single surface for status, usage, costs, bills, balance, proxy health, clients, and URL tests.
- **Router API** — the JSON HTTP seam the [Xirouter](https://github.com) Android app talks to (see `docs/adr/0002-router-json-api.md`; the app lives in `~/router-app`, contract in `API_CONTRACT.md`).
- **Scheduled alerts** — Samantel balance (daily + tiered warnings + realtime depletion monitor), per-device usage & cost (daily), proxy state changes (VLESS REALITY default, hysteria2 manual fallback), new devices, disk space, router reboots, monthly bill, Friday-discount reminder.
- **Usage & cost sharing** — per-device usage from nlbwmon, converted to Toman (full / Friday-discount rate, rounded to 1,000 Toman), with per-device share percentages; monthly billing from nightly snapshots.
- **Balance monitoring** — read-only Samantel integration with cached login, multi-package awareness, drain-rate projection, and a realtime monitor that catches same-day heavy usage.
- **Network enhancements** — DNS ad-blocking, completed SQM (CAKE both directions), Iran timezone, PassWall proxy monitoring (VLESS REALITY default, hysteria2 manual fallback, s-ui panel on the VPS).

## Documentation

| Doc | Contents |
|---|---|
| `docs/MONITORING_ALERTS.md` | Telegram bot, panel, commands, all alert triggers |
| `docs/USAGE_BILLING.md` | Per-device usage, Toman cost model, monthly bill |
| `docs/BALANCE.md` | Samantel balance feature incl. realtime depletion monitor |
| `docs/NETWORK_ENHANCEMENTS.md` | DNS ad-blocking, SQM, timezone |
| `docs/OPERATIONS.md` | Cron schedule, config files, troubleshooting, rollback |

## Repo layout & conventions

- `CONTEXT.md` — domain glossary (read before working here)
- `AGENTS.md` — agent guidance; `docs/agents/` — issue tracker / triage / domain docs
- `.scratch/` — specs (local-markdown issue tracker)
- The `.md` files at the repo root (`SYSTEM_ANALYSIS.md`, `API_DOCUMENTATION.md`, …) are **historical artifacts** of the abandoned Samantel automation project, kept for reference only.

## Security

No secrets live in this repo. Router credentials (bot token, Samantel password, SSH) live only in root-only config files **on the router** (`/etc/tg.conf`, `/etc/samantel.conf`, `/etc/billing.conf`).
