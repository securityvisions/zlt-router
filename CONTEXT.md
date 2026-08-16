# CONTEXT.md

Shared vocabulary for the home-network project. Use these terms exactly; don't drift to synonyms.

## Glossary

- **Router** — the Xiaomi Mi Router AX3000T running OpenWrt 25.12.5 at `192.168.1.1`. All automation runs here (not in this repo).
- **PassWall** — the VPN/proxy subsystem on the router (sing-box + xray + chinadns-ng). Provides the filtered-internet path.
- **REALITY-443-parsa** — the default proxy node: VLESS+REALITY on the VPS server `85.121.124.158:443` (SNI `www.bing.com`), served by the VPS's sing-box core. It is the global TCP node with no automatic failover; the fail-open watchdog switches the network to direct internet if it dies and auto-recovers when it is healthy again.
- **Hysteria2** — the secondary, manually-selectable proxy node (server `216.45.52.132:11609`), plus a Hysteria2 inbound on the VPS (`85.121.124.158:31800`, salamander obfuscation). "Proxy UP/DOWN" is measured by an HTTP 204 probe (Cloudflare `generate_204`) through the SOCKS port `1070`.
- **s-ui** — the VPS proxy panel running the sing-box core (replaces x-ui/xray): panel `:2095/app/`, subscription `:2096/sub/`.
- **nlbwmon** — bandwidth accounting on the router; `nlbw -c json -g mac` returns per-device totals. The per-user usage source.
- **Telegram bot** — @xirouterbot (token/chat in `/etc/tg.conf`). Sends alerts and hosts the interactive Panel.
- **Panel** — the bot's interactive inline-keyboard grid: Status, Proxy, Usage, Cost, Bill, Balance, Clients, Disk (one flat screen, 4 rows of 2). Tapping a button returns a Card.
- **Card** — a formatted reply message with a standard anatomy: title, divider, aligned value rows, freshness footer. The bot's unit of user-facing output.
- **Dashboard card** — the Panel's entry card: a compact live summary (data-plan balance, proxy state, devices, disk) from cached values, with the Panel grid beneath it.
- **Samantel** — the ISP (Iran). Its PWA API (`pwa.samantel.ir`) is queried read-only for data-package balance.
- **Remain counters** — Samantel `Remain` API fields, in KiB. `BalanceValue` = remaining (negative), `GrossBal` = quota. remaining GiB = |BalanceValue| ÷ 1048576.
- **Data plan** — the account-level internet offering exposed by the Router API; quota, remaining, and consumed amounts aggregate all current Packages.
- **Package** — one independently tracked Samantel allowance. The Router API exposes every Package with an opaque stable ID, provider/subscriber, verbatim ISP type/name, optional normalized category/window, amounts, dates, status, priority, and freshness. ISP-issued IDs are canonical; a persisted fingerprint ID exists only for migration when the ISP supplies none.
- **Toman** — cost unit (10 Toman = 1 Rial). Billing uses per-GB rates from `/etc/billing.conf` (7,700 T/GB full, 4,620 T/GB Friday).
- **Baseline** — the per-MAC snapshot in `/etc/usage-log/last`; daily usage is the diff vs this baseline.
- **Monthly log** — `/etc/usage-log/YYYY-MM.log`; the nightly snapshot appends per-device usage for monthly billing.
- **Alerts** — scheduled Telegram messages (balance, usage+cost, proxy state-change, new device, disk, reboot).
- **Router API** — the JSON HTTP surface served by uhttpd CGI (`/cgi-bin/routerapi.sh/*`), the seam the Xirouter app talks to. Reads and writes the same state files the bot uses; contract lives in `~/router-app/API_CONTRACT.md`.
- **API token** — the shared secret in `/etc/routerapp.conf` that gates the Router API. It is
  sent as HTTP Basic auth (`Authorization: Basic base64(xirouter:<token>)`; the username is
  fixed `xirouter`) because uhttpd does not forward custom `X-*` headers to CGI. The app's
  token field holds it; the bot is unaffected.
- **Telemetry log** — `/etc/telemetry/hourly.log`; the hourly `ts|total_gb|balance_gb|proxy_state` rows that feed the app's charts (the router's finer-grained history store beside the daily balance log).

## X28 smart edge (the WAN appliance)

- **X28** — the ZLT X28 4G/5G cellular router at `192.168.70.1`; the **only WAN path** the home network rides on. It holds the Samantel SIM (camping on MCI 5G NSA at this location; may show Rightel/Irancell/MCI depending on towers). Root access, v2rayA + xray-core, and the smart-edge scripts live here. See `router/x28/README.md`.
- **Link** — the X28's live connection state: operator (MCI preferred), PLMN (43211), tech (5G(NSA)/4G), RSRP (LTE anchor) / RSRP_5G (NR), signal level. Read via `/root/x28link.sh` → `linkstate.sh`.
- **Link stickiness** — keeping the X28 on the preferred operator: the `x28watch.sh` cron detects operator drift/degradation and re-selects MCI via `x28reselect.sh`.
- **Crypto engine** — the xray-core SOCKS service on the X28 (`:1080`, `/etc/init.d/x28proxy`) that terminates VLESS+REALITY to the VPS, offloading tunnel crypto from the AX3000T.
- **via_x28** — the PassWall node on the AX3000T pointing at the X28 crypto-engine SOCKS (`192.168.70.1:1080`); switching to it routes PassWall's proxied traffic through the X28.
- **Smart edge** — the role this effort gives the X28: link stickiness + link telemetry + management hardening + backup proxy engine, integrated into the existing home-network control plane.

## Resilience (the proxy path)

- **Fail-open** — the deliberate terminal state of the failover chain: when every proxy node fails its probe, PassWall drops to direct internet rather than taking the network down. The last rung of the chain, never the first.
  _Avoid_: direct mode, fallback (both used loosely elsewhere)

- **Degraded link** — a link that is alive but below the accepted quality threshold (weak signal, slow throughput). The watchdog escalates it separately from link-down; the preferred node stays in place until quality returns or the chain rotates.
  _Avoid_: slow, weak (informal)

- **Link quality** — the measured throughput/latency of the proxied path — how fast the tunnel is right now — as opposed to **link state** (what the modem is camped on). Probes assert aliveness; quality asserts speed.
  _Avoid_: health, speed (overloaded)
