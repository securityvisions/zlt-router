# 03 — Outage SLA Ledger

**What to build:** Internet outages become claimable evidence. The operator watchdog's existing direct-probe state transitions now append down/up rows (epoch, kind, detail) to one append-only Outage Ledger — the X28 records no Network Events today. A `/outages` command pairs consecutive transitions into durations and totals them per Jalali month: "MCI owed you 3h40m", with each outage's start/end/duration listed. The ledger tracks "no usable internet" only — routine tunnel node rotation must not inflate the SLA count.

**Blocked by:** 01 — Jalali module (monthly totals are keyed by Jalali month) and the batch snapshot.

**Status:** resolved

- [x] Ledger schema documented in the module header; appends are idempotent per transition (no duplicate down without an intervening up) — `hn_outage_pair` in hnlib, `HN_OUTAGE_LEDGER` env
- [x] Pairing function unit-tested: open down (no up yet), multiple complete cycles, cross-month-boundary attribution — 21 tests
- [x] Monthly totals accept a Jalali month key via the calendar module — `hn_outage_total` uses `hn_jalali_month_range` + overlap calc, handles open down via `HN_OUTAGE_NOW`
- [x] Watchdog glue is thin and best-effort: recorder failure can never block or delay operator switching — `add-down` on fail==threshold, `add-up` on recovery, `|| true`
- [x] Controlled simulation on the device (failing probe target via env override) writes exactly one down + one up pair — `HN_OUTAGE_LEDGER`/`HN_OUTAGE_NOW` fixtures
- [x] `/outages` Card renders month total plus a recent-outages list; suite green; health gate GREEN after deploy — `x28-outage-ledger.sh report [jalali-month]`, bot `/outages`

## Comments

Ledger at `/data/proxy/outage-ledger.log`, 5000-line bound, idempotent. Pairing via `hn_outage_pair`, totals via `hn_outage_total`, formatting via `hn_outage_format_duration`. Added to `operator-watchdog.sh` and `x28-bot.sh`.
