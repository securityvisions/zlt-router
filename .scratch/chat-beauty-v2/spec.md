# chat-beauty-v2 — Card rendering upgrade + in-place panel

**Status:** ready-for-agent

## Problem Statement

The bot's Panel replies already follow a Card anatomy, but they read as plain text: each button tap sends a *new* message (clutters the chat), and data-rich views have no visual form — the balance only shows as text, per-device usage as a plain list, history as nothing. The user wants the Panel to feel like a polished app screen, achievable without any new infrastructure.

## Design Decisions

1. **Chat-only beauty — no VPS, no web app.** The router is behind CGNAT (WAN is a private `192.168.70.167`) with ~14.8 MB free flash. A true Telegram Mini App requires public HTTPS, which is impossible without a VPS or a third-party tunnel agent (too large, ephemeral URL, data flows through a third party). Declined. All beauty lives inside Telegram messages.
2. **Edit-in-place Panel.** `/panel` sends *one* persistent message (Dashboard card + button grid) and stores its `message_id`; every button tap **edits that same message** — the text above the grid swaps between dashboard and result while the grid stays. Falls back to a new message if an edit ever fails. This is the biggest "app-feel" win.
3. **Real visualizations from existing router data:** gauge bars (balance quota, disk, temp/ram), per-device usage bars scaled to the top consumer, and a balance-trend sparkline from the nightly `/etc/balance-log` daily `GB` series (`▁▂▃▄▅▆▇█` blocks).
4. **Card anatomy v2** across all Panel and slash replies: title, section rule, aligned monospace value columns, tier badges 🟢/🟠/🔴, freshness footer.
5. **`tg.sh` alert messages** (device joined, balance notice, disk, reboot) restyled to the same Card language for consistency. *(Included per user approval of ticket 06.)*

## Architecture Note

All bot output goes through the shared rendering helpers introduced in ticket 01 (`bar`, `spark`, column padding, `card` v2). Later tickets only compose those helpers — no duplicate logic. Data sources are already on the router: `/proc`, `df`, `free`, `/root/usage.sh`, `/tmp/balance_report`, `/etc/balance-log`, `/tmp/dhcp.leases`. State for the in-place Panel lives in a small file on the router.

## Tickets (dependency order)

| # | Ticket | Blocked by |
|---|--------|-----------|
| 01 | Card v2 rendering core + Status demo | none |
| 02 | Edit-in-place Panel | 01 |
| 03 | Balance card: gauge + trend sparkline | 01 |
| 04 | Device cards: per-device usage bars | 01 |
| 05 | Dashboard v2 sweep (remaining commands) | 03, 04 |
| 06 | tg.sh alerts restyle | 01 |

## Verification Seam

The bot's reply surface in Telegram:
- A command tap returns a Card with the v2 anatomy, rendered without HTML-parsing errors.
- A `/panel` tap posts one message; subsequent taps mutate *that same message* rather than appending.
- Gauge/sparkline blocks render as intended (watch for multi-byte char issues in the monospace `<pre>` block).
- `/tmp/botcmd.log` records callbacks and any send/edit API errors; no error spam.

## Out of Scope

LAN web dashboard, true Telegram Mini App, VPS involvement, interactive web controls (deferred), deeper per-device daily history charts (data not yet collected).