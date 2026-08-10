# Bot panel redesign + wedge self-healing

## Status: ready-for-agent (implemented)

## Problem Statement

Two issues, one root cause shared.

1. **`balance` command stopped working.** `balance.sh --report` still worked from the CLI (89 GB remaining, exit 0); the handler in `botcmd.sh` was correctly wired. The real failure was a **wedged long-poll loop** (PID 4038): alive since Aug 9 23:55, empty log, blocked on open pipes with no writer. The whole panel was dead, not just balance. The cron respawner `botcmd-start.sh` used only a `kill -0` (PID liveness) guard, so a wedged-but-alive process was never restarted and stayed dead for 18+ hours.
2. **Panel wanted to look polished.** The bot replies were plain-text cards with a terse one-line panel prompt.

## Design decisions (from the grilling session)

- **Q1 — Restart the wedged poller now.** Done: killed PID 4038; the cron respawner brought it back within 60s.
- **Q2 — Heartbeat watchdog, not deep root-cause diagnosis of the BusyBox-ash wedge.** The loop stamps `/tmp/botcmd.hb` each iteration; the cron watcher kills + respawns if the heartbeat is stale. Catches *any* wedge mechanism.
- **Q3 — Balance served from cache.** The panel reads `/tmp/balance_report` + `/tmp/balance_report.ts` (refreshed every 15 min by the balance cron) with a "cached as of HH:MM" footnote. Live ISP calls no longer run inside the single-threaded loop — eliminating the most likely future wedge trigger. Fall back to `balance.sh --report` if no cache exists.
- **Q7 — Watchdog threshold: 120s.** Normal loop iterations can legally idle up to ~30s (long-poll timeout=25 + retry sleep). 120s tolerates 3-4 silent iterations and recovers in ~2 minutes.
- **Q4 — Flat single-screen panel**, 4 rows of 2, domain-ordered (Network / Data / Billing / Devices). Buttons unchanged: Status, Proxy, Usage, Cost, Bill, Balance, Clients, Disk.
- **Q5 — HTML `parse_mode`** on every message (all botcmd output).
- **Q6/Q10 — Dashboard entry card.** `/panel` returns a summary card (data balance, proxy state, devices online + today's usage, disk, load/temp) with the button grid beneath it.
- **Q9/Q11 — Decorated card anatomy, mixed rendering.** `<b>` title line, `──────────────` divider, `<pre>` monospace block for aligned values, italic freshness footer. HTML header + code-block table.
- **Q12 — All botcmd output (panel + slash commands) goes through the card template.** `tg.sh` alert messages are a separate channel and unchanged.
- **Q13 — No "refresh now" button.** Pure cache; the 15-min monitor refresh suffices.

## Router changes

- `/root/botcmd.sh` — rewritten: `send()` sends `parse_mode=HTML`; `card()`/`esc()` helpers; dashboard `panel()`; `cmd_balance()` reads cache; heartbeat stamp at the top of the long-poll loop; all card outputs restyled.
- `/root/botcmd-start.sh` — rewritten: heartbeat watchdog (stale > 120s → kill + respawn), safe rollout (a pre-heartbeat process is left running).
- `/root/balance.sh` — `--report` tees to `/tmp/balance_report` + writes `/tmp/balance_report.ts`; new `--cache` mode; `monitor()` refreshes the cache (free when it already fetched rows, one extra API call only when the cache is > 15 min stale).

## Testing / verification seam

The bot's output layer (same seam used to diagnose the wedge):

1. **Loop health:** `/tmp/botcmd.hb` mtime must advance continuously (checked by the wrapper cron every 60s); `/tmp/botcmd.log` shows heartbeats/callbacks.
2. **Panel render:** tap `/panel` or any button in Telegram — the reply should be a dashboard card with the decorated anatomy, rendered without HTML-parsing errors (no raw `&lt;`-style entities leaking).
3. **Balance:** the `📦 Balance` card should show the cached report (as-of timestamp) and return instantly even if the ISP API is slow/down (fallback covers missing cache).
4. **Watchdog:** with the log file, simulate staleness and confirm respawn (`logger -t botcmd-start` shows the kill).

## Out of scope

- `tg.sh` alert styling (separate channel).
- Deep diagnosis of the exact BusyBox-ash pipe-wedge mechanism.
- Per-device dashboard lines / "refresh now" button.