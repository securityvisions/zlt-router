# Xirouter — the router companion app

Status: ready-for-agent (implemented)

## Problem Statement

The home network is monitored and operated through a Telegram bot (@xirouterbot): status,
usage, cost, bill, balance, proxy health, clients, disk, plus device naming/watching. The
data lives in shell scripts and state files on the router (Xiaomi AX3000T, OpenWrt), and the
only machine surface is Telegram. The user wants a **richer companion app** — like the
chandtoman Android app — with statistics and charts, a Persian RTL UI, and the useful features
the bot lacks (real charts, live bandwidth, direct actions, in-app notifications).

## Solution

Two pieces, one seam:

- **Router JSON API** — uhttpd CGI (`/cgi-bin/routerapi.sh/*`) reading/writing the same state
  files the bot uses, gated by a shared token (`/etc/routerapp.conf`). Auth is HTTP Basic
  (`Authorization: Basic base64(xirouter:<token>)`; token = password, username fixed
  `xirouter`) — uhttpd drops custom `X-*` headers, so a plain header token never reaches the
  CGI. Contract in `~/router-app/API_CONTRACT.md`. Plus an hourly telemetry snapshot for charts.
- **Xirouter Android app** (`~/router-app`) — Kotlin/Compose, Persian RTL, OkHttp +
  kotlinx-serialization, Room local history, WorkManager notifications.

### Design decisions

- **Home-first, remote later** — the API is plain JSON over HTTP; a Cloudflare Worker relay
  (phase 2, not built) can push snapshots out without changing the seam. **No VPS** in the path.
- **The Telegram bot stays as-is**; the app is an additional surface. Notifications in the app
  mirror the bot's alert rules; the first poll baselines silently.
- **One state, two surfaces** — the API writes `user-names`, `watchlist`, `LAST_FRIDAY`; names
  and the Friday flag set in the app show up in bot reports and vice versa.
- **Phone is a second history store** — Room keeps a sample per poll (12-month retention,
  pruned); charts merge router history + local samples.
- **Charts are hand-rolled Compose Canvas** with Persian digits (chandtoman's legibility ethos).
- **Actions are guarded** — every action confirms; destructive ones require the optional PIN app lock.
- **Cost model** is the bot's documented one: rate × GB (7,700 full / 4,620 Friday), rounded to
  the nearest 1,000 Toman, per-device share %.

### Delivered-state notes (auth transport, from live deployment)

The original plan sent the token in an `X-Router-Token` header. Live deployment proved that
**uhttpd only forwards a fixed whitelist of request headers to CGI** (HTTP_ACCEPT, HTTP_COOKIE,
HTTP_AUTHORIZATION, HTTP_HOST, HTTP_REFERER, HTTP_USER_AGENT, …) and silently drops custom
`X-*` headers, so the header design could never authenticate. The seam now uses **HTTP Basic
auth** end-to-end:

- Router: `ra_authed` accepts `Authorization: Basic base64(xirouter:<token>)` (token as the
  password, username ignored); the legacy `X-Router-Token` header is still accepted by the lib
  for back-compat and in-shell tests.
- App: `ApiClient` sends the Basic header (username `xirouter`); the token field in Settings is
  unchanged.
- Deployment also fixed three adjacent defects: the CGI dispatcher lost the status code in a
  subshell (every response was HTTP 200) — `ra_route` now emits a `@@STATUS:NNN` marker the
  dispatcher strips; uhttpd ignores a bare `Status: NNN` and needs the reason phrase; and
  `ra_json_bill` emitted a trailing `}` (invalid JSON the app's strict decoder rejected).
  See `issues/13-router-api-auth-transport.md`.

## Out of scope

- Cloudflare Worker relay (phase 2, sketched only).
- Deploying to the router from this repo (the scripts' canonical copies are in
  `~/home-network/router/`; deploy steps in `~/home-network/docs/OPERATIONS.md`).
