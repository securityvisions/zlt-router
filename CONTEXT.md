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
- **Toman** — cost unit (10 Toman = 1 Rial). Billing uses per-GB rates from `/etc/billing.conf` (7,700 T/GB full, 4,620 T/GB Friday).
- **Baseline** — the per-MAC snapshot in `/etc/usage-log/last`; daily usage is the diff vs this baseline.
- **Monthly log** — `/etc/usage-log/YYYY-MM.log`; the nightly snapshot appends per-device usage for monthly billing.
- **Alerts** — scheduled Telegram messages (balance, usage+cost, proxy state-change, new device, disk, reboot).
