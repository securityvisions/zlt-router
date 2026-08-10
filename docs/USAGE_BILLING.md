# Usage & Cost Sharing (per-device billing)

Per-device internet usage is measured by **nlbwmon** (native DB, queried with `nlbw -c json -g mac`), converted to a **Toman** cost table, and reported daily + monthly via Telegram.

## Data sources

- **Usage**: nlbwmon → `nlbw -c json -g mac` returns per-MAC `rx_bytes` + `tx_bytes` totals. The router's own interfaces and the multicast address are excluded.
- **Device names**: joined from `/tmp/dhcp.leases`; unmatched devices appear as `Unknown-<mac-prefix>` and are still billed (all non-router MACs are included).
- **Rates** (`/etc/billing.conf`): per-GB Toman — full **7,700 T/GB**, Friday-discount **4,620 T/GB** (derived from the 150 GB / 365-day package: 11,550,000 IRR full / 6,930,000 IRR Friday).
- **Rounding**: each cost rounds to the nearest **1,000 Toman**; each device shows its **share %** of the total.

## Daily vs monthly accounting

- **"Today"** = the per-MAC diff vs a baseline snapshot stored at `/etc/usage-log/last`.
- **Nightly snapshot** (23:55, `usage.sh --snapshot`) appends each day's per-device usage to `/etc/usage-log/YYYY-MM.log` (idempotent per day) and updates the baseline.
- **Monthly bill** = sum of the per-month log, sent on the 1st via `monthly.sh`.
- **Current-period fallback**: before the first baseline or when today's diff is ~0, reports fall back to the nlbwmon cumulative period (labeled with the start date) so the report always shows real numbers.

## Bot commands

- `/usage` — today's (or current-period) per-device GB
- `/cost` — today's usage + cost table; asks **Yes/No** for the Friday discount, then shows Toman + share %
- `/bill` — same for the current month
- `/friday yes|no` — store the default used by the scheduled reports (the last Yes/No answer from the bot is remembered too)

## Scheduled reports

- **Daily 21:30** — `usage.sh --report` sends `billing.sh --today` (uses the stored Friday flag).
- **1st of month 07:00** — `monthly.sh` sends the previous month's bill.

## Implementation notes

- `usage.sh`: `--today`, `--snapshot`, `--month [YYYY-MM]`, `--raw`, `--report`
- `billing.sh`: `--today [yes|no]`, `--month [yes|no] [YYYY-MM]` — builds the Toman table with thousands separators, rounding, and share %
- Monthly logs are tiny text files (~10 KB/month max); all runtime state is otherwise in `/tmp`

## Files on the router

- `/root/usage.sh`, `/root/billing.sh`, `/root/monthly.sh`
- `/etc/billing.conf` (root-only): rates, rounding, `LAST_FRIDAY`, `FRIDAY_REMINDER`
- `/etc/usage-log/` — `last` (baseline) + `YYYY-MM.log` (monthly)
