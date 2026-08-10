# Balance Monitoring (Samantel)

Read-only monitoring of the Samantel internet package balance, with cached login, multi-package awareness, drain-rate projection, tiered alerts, and a realtime depletion monitor.

## How the data works

- **Endpoint**: Samantel PWA `Remain` API (read-only). Requires an auth token obtained via the NextAuth flow: CSRF → credentials login (`isOtp=false`) → session → Bearer access token.
- **Units**: the counters are KiB. `GrossBal` = quota, `BalanceValue` = remaining (negative). So `remaining GiB = |BalanceValue| / 1048576`.
- **Lag**: the ISP counters update slowly (batch-style) — a real download may not show for some time. The system treats the numbers as "as reported by the ISP" and works around the lag with a realtime monitor + safety margins.
- **Multi-package**: every `Benefit Data` entry is read (quota, remaining, expiry). The one with the most remaining is the **main** package; the **total** is the sum across plans; exhausted plans are compressed to one muted line.

## Auth caching

- The access token is cached at `/tmp/samantel_token` (mode 600) with a ~28-day expiry.
- Every check reuses it; an auth-failed response (`statusCode 6`) clears the cache, re-logs in, and retries once.
- Result: a balance check is ~0.4 s instead of ~5 s, and recovery from expiry is automatic.

## Report (`/balance`, daily 07:00)

```
📦 Samantel — 146.5 GB left across 1 plan(s)
Main: 150 GB · 146.5 GB left (97%) · expires 2027-08-05 (~363d)
+1 expired plan(s)

Drain ~3.5 GB/day → ~41d left (est. — ISP updates slowly)
```

- Shows total, main package quota/remaining/percentage, days to expiry, and the **drain rate + projected days left** once history has accumulated.

## Balance history & drain rate

- Every successful daily check snapshots `date|total` into `/etc/balance-log/YYYY-MM.log`.
- The drain rate is computed from **consecutive positive deltas only** — days where the total *rose* (a new package was purchased) are skipped, so a purchase never corrupts the projection.
- Projection = total ÷ rate; until a few nights of snapshots exist it reports "collecting data".

## Tiered alerts (per-tier state, alert on escalation only)

| Tier | Condition | Message |
|---|---|---|
| 🔶 notice | <25% left OR projected <30 d | heads-up |
| 🟠 warn | <10 GB OR <7 d to expiry OR projected <14 d | "consider renewing" |
| 🔴 urgent | <3 GB OR <3 d OR projected <7 d | "renew soon — Friday is 40% off!" |
| 📛 exhausted | total < 0.05 GB | "data exhausted — renew now" |

The tier state resets silently downward when data improves (e.g., after a purchase). Thresholds are configurable in `/etc/samantel.conf`.

## Realtime depletion monitor (`--monitor`, every 15 min)

Catches the **"big download day"** case that the lagged ISP counter would otherwise hide until morning:

1. **Anchor** — every confirmed ISP reading stores `{time, total, main quota, nlbw total, min expiry}`.
2. **Estimate** — every 15 min: `estimated = anchor total − (current nlbw total − anchor nlbw total)` (nlbwmon is real-time).
3. **Alert** — the same tier logic runs on the *estimate*; a rate alert fires when consumption is **≥5 GB/h while estimated remaining <30 GB** (throttled to once per 4 h): `⚡ ~8 GB/h → ~6h left — pause heavy downloads to save data.`
4. **Re-anchor** — every 60 min (or on a tier cross) it re-fetches the ISP reading and absorbs the lagged updates.

**Honest limit**: because of ISP lag the estimate can be optimistic by roughly `lag × rate`; the 10 GB warn margin and the rate alert exist to cover that.

## Files on the router

- `/root/balance.sh` — `--report`, `--daily`, `--check`, `--monitor`
- `/etc/samantel.conf` (root-only) — phone, password, thresholds (`BALANCE_WARN_GB`, `BALANCE_URGENT_GB`, `BALANCE_WARN_DAYS`, `BALANCE_URGENT_DAYS`, `BALANCE_RATE_ALERT_GBH`, `MONITOR_REFRESH_MIN`)
- `/etc/balance-log/` — `YYYY-MM.log` history
- `/tmp/` — token cache, anchor, tier/rate state
