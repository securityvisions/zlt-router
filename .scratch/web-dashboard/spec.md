# Web Dashboard (Xirouter NOC) — Spec

Phase 0 + Phase 1 of the web dashboard that becomes the primary product surface
(ADR-0004). The dashboard is a Network Operations Center: derived Network Health
Score, live status, the Network Event log, the X28 link, and hourly link-quality
history. Web app frozen the Android app; new domain work lands here only.

## Settled decisions (grilling session 2026-08-16)

- **Role:** full product on the web; the Android app is frozen (ADR-0004).
- **Data strategy:** existing Router API + three collectors — Network Event log,
  service-health probe, quality-history rollup. Health Score is *derived*, never
  a sensor (ADR-0005).
- **Scope:** all 55 points, six phases: **Monitor → Understand → Control →
  Account → Automate → Diagnose**. This spec covers Phase 0 (data foundation)
  and Phase 1 (Monitor dashboard).
- **Stack:** Vite + React + Tailwind, RTL-first, Persian typography (Vazirmatn),
  Dark-mode-only OLED palette (green #22C55E accent, data-dense) per
  ui-ux-pro-max. Compiled `dist/` is committed and deployed to `/www/noc`,
  same-origin with the Router API (`/cgi-bin/routerapi.sh`), token-gated.
- **Health Score:** 100 − penalties: Link quality (30), Proxy state (20),
  Service health (20, −5/service), Freshness (15, >10min −5, >60min −15), DNS
  (15, success<98% −15, latency>200ms −8). Bands: Excellent ≥90, Good ≥75,
  Degraded ≥50, Poor <50.
- **Event catalog** (13 kinds, recorded via one shared `hn_event record` helper,
  served by `/events`): internet_up/down, node_rotated, operator_reselected,
  device_joined, device_blocked/approved, proxy_changed, package_threshold,
  quality_degraded/recovered, router_rebooted, dns_unhealthy.

## Phase 0 — data foundation (router side, all live in this repo)

- Network Event log: `hn_event_catalog` + `hn_event_record` + `hn_event_list`
  in hnlib.sh; `/events` API (limit, category filters).
- Event instrumentation: failopen/autorecover/x28watch (internet, node,
  operator, quality), devicewatch/quarantine (device), proxy switch + reboot +
  forecast (proxy, router, package).
- Service-health probe: `hn_svc_probe` + `hn_svc_penalty` (init-service seam).
- DNS health seam: `dns-stats.sh` + `hn_dns_stats` + `hn_dns_penalty`.
- Health Score: pure `hn_health_score` + `hn_health_band`; `/health` API with
  per-component breakdown.
- Quality rollup: `hn_quality_series`; `/quality` API (hours filter).

## Phase 1 — Monitor dashboard (web/)

- Vite + React + Tailwind RTL SPA, `web/` directory. Dark OLED design system.
- Token setup screen (localStorage) + Basic-auth API client.
- Dashboard cards: health gauge, status strip, link card, quality chart,
  events feed. Each card polls its own endpoint.

## Later phases (ticketed at their start)

Phase 2 Understand (devices/people/packages/analytics), Phase 3 Control (live
traffic/proxy/DNS/routing), Phase 4 Account (ledger/payments/reports), Phase 5
Automate + Diagnose.

## Tracking

Tickets: `.scratch/web-dashboard/issues/`. Router tests: `router/tests/run.sh`.
Web tests: `web/npm test` (vitest); typecheck: `web/npm run typecheck`.
