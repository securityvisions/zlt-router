# Spec: Router Alerting, Usage & Billing via Telegram

Status: ready-for-agent

## Problem Statement

The user's home network runs on a Xiaomi Mi Router AX3000T (OpenWrt 25.12.5) that also operates a PassWall VPN/proxy whose active path is a Hysteria2 node. Nobody can tell, without SSH-ing into the router:

- how much data each person/device is using,
- how much data is left on the Samantel internet package (and when it expires),
- whether the proxy (Hysteria) is currently working,
- when a new device joins, when storage is nearly full, or when the router reboots.

The household shares one internet bill, but costs can't be attributed per user because there is no per-device usage accounting, and no per-person cost calculation. Everything requires manual SSH commands and mental arithmetic.

## Solution

A self-contained alerting and reporting system that runs entirely on the router and communicates with the user through a Telegram bot (@xirouterbot):

- **Scheduled Telegram alerts** — package balance (daily + low-balance warning), per-device usage and cost (daily), Hysteria proxy state changes, new devices, disk space, and router reboots.
- **An interactive bot with a button panel** — on-demand status, usage, cost, bill, balance, proxy, clients, disk, and URL tests, without needing to remember commands.
- **Fair cost-sharing** — per-device usage in GB, converted to Toman using a per-GB rate, with an optional 40% Friday discount chosen via a tap, rounded to the nearest 1,000 Toman, with each device's share of the total.
- **Monthly billing** — nightly usage snapshots accumulate into a monthly log; the 1st of each month sends the previous month's bill.

The system is tiny (one small JSON-parsing package plus ~10 KB of shell scripts), survives reboots (cron + auto-start), fails silently when offline, and holds secrets in root-only config files.

## User Stories

1. As a household member, I want to receive a Telegram message when the proxy (Hysteria) goes down, so I immediately know internet is degraded.
2. As a household member, I want to be notified when the proxy comes back up, so I know service is restored.
3. As the account owner, I want a daily Telegram message showing how much data is left on my Samantel package and when it expires, so I can plan renewals.
4. As the account owner, I want a warning when the remaining package data drops below a threshold (5 GB) or expiry is near (7 days), so I never run out of internet.
5. As the account owner, I want to see each data package's quota, remaining data, and expiry date, so I understand my full balance situation.
6. As a household member, I want to see how much internet each device has used, so I understand who consumes what.
7. As the bill payer, I want the cost of each device's usage in Toman, so each person can pay their fair share.
8. As the bill payer, I want costs rounded to the nearest 1,000 Toman, so amounts are clean and collectable.
9. As the bill payer, I want each device's percentage share of the total, so contributions are transparent.
10. As the bill payer, I want the cost calculation to account for the 40% Friday discount when I bought the package on a Friday, so amounts are correct.
11. As the bill payer, I want to answer the Friday-discount question with a single button tap (yes/no), so I don't have to type.
12. As the bill payer, I want the Friday answer I last gave to be remembered for scheduled reports, so I only answer when I actually ask.
13. As the bill payer, I want a monthly bill summary of the previous month, so I can collect contributions at the end of each month.
14. As a user, I want a daily usage-and-cost report at a fixed time, so I can review usage without asking.
15. As a user, I want to query the bot on demand with commands such as status, usage, cost, bill, balance, proxy, clients, disk, and URL test, so I don't need to SSH into the router.
16. As a user, I want a button panel instead of memorizing commands, so checking the router is one tap.
17. As a user, I want a notification when a new device joins the network, so I am aware of who connects.
18. As the admin, I want a warning when router storage exceeds 85%, so I can free space before it becomes critical.
19. As the admin, I want a Telegram message when the router comes back online after a reboot, so I know the network is restored.
20. As the admin, I want the system to survive reboots, so alerts continue after a power cycle.
21. As the admin, I want the system to auto-restart if the bot process dies, so monitoring never silently stops.
22. As the admin, I want the system to use minimal storage and RAM, so it fits the router's limited flash (16 MB free).
23. As the admin, I want alerts to reach me even when the proxy is down, so failure reporting doesn't depend on the failing proxy.
24. As the admin, I want the bot to respond only to my Telegram chat, so strangers can't query the router.
25. As the admin, I want all credentials stored in root-only files, so secrets aren't exposed.
26. As a user, I want the system to fail silently when offline, so no errors spam the bot.
27. As the admin, I want activity logged to a file, so I can troubleshoot.
28. As the account owner, I want the balance report to show the total data remaining across all packages, so I know the real number.
29. As the bill payer, I want devices without a known hostname still included in billing (labeled as unknown), so usage is never silently excluded.
30. As a user, I want the bot to answer a URL test (HTTP status + latency) for any address, so I can check reachability from the router.
31. As a user, I want to set the default Friday-discount flag with a command, so scheduled reports use the right rate.
32. As the admin, I want the bot's button results to include a way back to the panel, so navigation stays simple.

## Implementation Decisions

### Modules

- **Alert helper** — a shared Telegram send function (HTML parse mode, short timeout, logs to a file, fails silently). Source of truth for the bot token and chat ID. Also implements the disk-threshold and reboot-status messages.
- **Usage accounting** — reads per-device totals from nlbwmon via its native query tool (`nlbw -c json -g mac`), which returns per-MAC rx/tx byte totals. Filters out the router's own interfaces and the multicast address. Resolves device names from DHCP leases, falling back to "Unknown-<mac-prefix>".
- **Daily/monthly state** — a per-MAC baseline snapshot; "today" is the diff vs that baseline; a nightly snapshot appends each day's usage to a per-month log file, making the monthly bill possible without long retention in nlbwmon.
- **Billing** — converts usage lines to a Toman table: per-GB rate × GB, rounded to the nearest 1,000 Toman, with a per-device share percentage and a total. Rate comes from config (full vs Friday).
- **Balance checker** — read-only Samantel integration: NextAuth login flow, then the Remain endpoint. Parses the data packages (quota, remaining, expiry) and exposes a report plus a low-balance alert.
- **Hysteria monitor** — probes the proxy via the SOCKS port using an HTTP 204 target; labels the active node from the running PassWall config; alerts only on state change (UP ↔ DOWN).
- **Device watcher** — diffs DHCP leases against a known set and alerts on new MACs.
- **Interactive bot** — a background long-poll loop over `getUpdates`, with command handling, an inline-keyboard button panel, and callback-query handling for taps (including the Friday yes/no flow). Guarded by a PID-based start script so only one instance runs.
- **Monthly reporter** — sends the previous month's bill on the 1st.

### Telegram integration

- The Bot API is plain HTTPS; the router reaches it directly (verified ~1.1 s) with a SOCKS fallback path available.
- Messages: `sendMessage` with `parse_mode=HTML`.
- Panel: `reply_markup` inline keyboards with `callback_data`; results carry a "back to panel" button.
- Command flow: user-invoked `/cost` and `/bill` first present a Yes/No Friday question as buttons; the tap's callback data carries the intent, so no stateful conversation tracking is needed.

### Balance semantics (calibrated empirically)

- Samantel `Remain` counters are in KiB. `GrossBal` is the quota (negative), `BalanceValue` is the remaining (negative). Remaining GiB = |BalanceValue| ÷ 1,048,576.
- The ISP counters update slowly (not in real time), so the report reflects the ISP's own view.
- The active package is the one with the most remaining; a secondary (benefit) package may also appear.
- Low-balance conditions: total remaining < 5 GB OR any package expires within 7 days; the alert fires once per day.

### Cost model

- Rates live in a config file, expressed in Toman per GB: full 7,700 and Friday 4,620 (derived from the 150 GB / 365-day package at 11,550,000 IRR full / 6,930,000 IRR Friday-discounted).
- All amounts are displayed in Toman (10 Toman = 1 Rial).
- The bot's Friday answer is persisted as the default used by scheduled reports.

### Scheduling & resilience

- Cron: proxy check every 5 min; disk check every 30 min; balance report daily 07:00; usage+cost report daily 21:00; nightly usage snapshot 23:55; monthly bill on the 1st; device watcher every minute; bot guard every minute.
- Boot: a reboot alert and bot startup are wired into the router's boot sequence.
- All runtime state lives in RAM (`/tmp`); only configs and the monthly log persist on flash.

### Dependencies & security

- One new package: a lightweight JSON parser (jq). No Python, no sqlite.
- Secrets (bot token, Samantel credentials, rates) live in root-only config files on the router; the bot filters to a single authorized chat ID.

## Testing Decisions

### What makes a good test

Test external behavior only: the observable Telegram message, the reported balance matching the ISP's app, the usage matching nlbwmon's own output, and the cost math matching hand-computed values. Don't assert script internals.

### Modules to test

- **Alert helper** — a test message actually lands in the chat (verified via `getMe` and a sent message).
- **Balance** — the login flow returns a session, the Remain call succeeds, the parsed remaining matches the known package state (150 GiB plan with ~149.9 GiB remaining), and the low-balance alert fires only when a condition triggers.
- **Usage/Billing** — the per-device table matches `nlbw -c json -g mac`; the cost table at both rates (full and Friday) matches hand-computed values for sample GB amounts, including rounding and shares.
- **Bot** — command responses, the button panel markup is valid JSON, a callback query (button tap) produces the right result, and the Friday yes/no flow updates the stored default.
- **Hysteria** — the 204 probe result and the state-change alert fire only on UP↔DOWN transitions (first run baselines silently).
- **Device watcher** — a new lease triggers exactly one alert; no alert on unchanged leases.
- **Cron integration** — each scheduled script runs correctly when invoked the way cron invokes it.

### Prior art

The build was verified live: the bot token was validated, a test message was delivered, the balance report was checked against the active 150 GiB package, the cost math was spot-checked against sample values (e.g., 10 GB @ 7,700 T/GB → 77,000 T), the panel JSON was validated, and the bot processed button taps from the phone.

## Out of Scope

1. **Automatic package purchase/payment** — the earlier abandoned Samantel automation project (OTP listener, payment flow) is out of scope; this system only reads balance.
2. **Bank card details** — never stored or processed.
3. **Multi-router support** — single-router deployment.
4. **Historical analytics or dashboards** — daily/monthly text reports only.
5. **SMS or email alerts** — Telegram only.
6. **Localization** — messages are in English.
7. **Remote control** (reboot / wake-on-LAN / toggling WiFi) — explicitly not included.
8. **Per-device QoS or bandwidth caps** — reporting only.

## Further Notes

- The ISP's balance counters update slowly; the reported numbers may lag real usage. The divisor in the balance module is configurable if the ISP changes units.
- The 80 GiB plan shown by the ISP is a secondary benefit package; the primary billable package is the 150 GiB one.
- The legacy markdown documents in the repo root describe the abandoned automation project and are kept only as historical artifacts.
- This spec is a retrospective spec of the system as deployed (Status: ready-for-agent) — the implementation is already on the router, so tickets derived from it should focus on enhancements, fixes, or documentation, not greenfield build-out.
