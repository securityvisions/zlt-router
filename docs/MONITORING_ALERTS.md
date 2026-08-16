# Monitoring & Alerts (Telegram bot)

The router communicates with the user through a Telegram bot (**@xirouterbot**). All alerting, reporting, and on-demand queries go through it.

## Bot surface

### Button panel
Send `/panel` (or `/start`, `/menu`) to get an inline-keyboard panel:

```
📊 Status   🟢 Proxy
📈 Usage    💰 Cost
🧾 Bill     📦 Balance
📱 Clients  💾 Disk
```

Tapping a button returns the result instantly; every result includes a **◀ Panel** button to return. `💰 Cost` and `🧾 Bill` first ask a **Yes/No** question about the Friday discount, then show the Toman table.

### Text commands
| Command | Returns |
|---|---|
| `/status` | uptime, load, RAM, temp, storage |
| `/usage` | today's (or current-period) per-device usage |
| `/cost` | today's usage + cost table (Toman, share %) |
| `/bill` | this month's bill (Toman) |
| `/balance` | Samantel data left, expiry, drain rate, projection |
| `/hyst` | proxy status + latency (active node: REALITY-443-parsa by default, hysteria2 if switched) |
| `/clients` | connected devices (DHCP leases) |
| `/test <url>` | HTTP status + latency for any URL from the router |
| `/disk` | storage breakdown |
| `/friday yes\|no` | set the default Friday-discount flag for scheduled reports |
| `/fridayremind on\|off` | toggle the Friday-discount reminder |
| `/help` | command list |

The bot only responds to the authorized chat ID configured in `/etc/tg.conf`.

## Alert triggers (cron)

| When | What |
|---|---|
| every 5 min | **Proxy state change** (🔴 DOWN / 🟢 UP) — alerts only on transition, not per-check |
| every 5 min | **Link stickiness** — X28 operator drift/degradation, re-selected to MCI (`x28watch.sh`) |
| every 10 min | **VPS origin** — panel/sub ports unreachable (`vpshealth.sh`) |
| every 30 min | **Disk space** — alerts only when storage > 85% |
| 03:00 daily | **Backup** — nightly snapshot written; failure reported (`backup.sh`) |
| 06:30 daily | **Speedtest** — measured Mbps below the floor (default 10); failure to measure reported (`speedtest.sh`) |
| 07:00 daily | **Balance report** + tiered low-data warnings (see `BALANCE.md`) |
| 21:30 daily | **Usage + cost report** per device (Toman) |
| every min | **New device joined** (DHCP lease diff) |
| every 15 min | **Realtime balance monitor** — catches same-day heavy usage (see `BALANCE.md`) |
| 1st of month 07:00 | **Monthly bill** for the previous month |
| Friday 09:00 | **Friday-discount reminder** (toggleable) |
| degraded window | **Degraded link** — alive but below quality floor, distinct from link-down |
| on boot | **"Router back online"** + bot auto-start |

## Implementation notes

- **`tg.sh`** is the shared send helper: HTTPS `sendMessage` with HTML parse mode, short timeout, logs to `/tmp/tg.log`, fails silently offline. Also implements `--disk` and `--reboot` messages.
- **`botcmd.sh`** is a background long-poll loop (`getUpdates`) with a PID-based single-instance guard; **`botcmd-start.sh`** (cron, every minute) restarts it if it dies.
- **`hyst.sh`** probes the proxy via SOCKS port 1070 against Cloudflare's HTTP 204 endpoint, labels the active node from the running PassWall config (e.g. `Auto (REALITY-443-parsa, hysteria2-11609)`), and alerts on state change (first run baselines silently).
- **`devicewatch.sh`** diffs DHCP leases against a known-MAC list and alerts on new devices (baselines on first run).

## Files on the router

- `/root/tg.sh`, `/root/botcmd.sh`, `/root/botcmd-start.sh`, `/root/hyst.sh`, `/root/devicewatch.sh`
- `/etc/tg.conf` (root-only): bot token + chat ID
- Runtime state in `/tmp` (`botcmd.log`, `tg.log`, `hyst_state`, `devices_known`, `botcmd.lock`, `botcmd.pid`)
