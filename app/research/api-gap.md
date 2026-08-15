# API gap analysis: which dashboard features need new router endpoints?

Wayfinder research ticket. Sources read (cited throughout):

- Router server: `~/home-network/router/routerapi.sh`, `routerapi_lib.sh`, `balance.sh`, `billing.sh`, `devicewatch.sh`, `snap.sh`, `hnlib.sh`, `router/tests/*`
- Docs: `~/home-network/CONTEXT.md`, `~/home-network/API_DOCUMENTATION.md`
- App contract + code: `~/router-app/API_CONTRACT.md`, `app/src/main/java/ir/parsavisions/xirouter/{Api,ApiClient,XirouterViewModel,SnapshotPollingCycle,AndroidSnapshotCycleRuntime,LedgerKeeper,Packages,Db,Notify,ChartMath}.kt`, `app/.../ui/Data.kt`

Verbatim endpoint list (the router's dispatcher) — `routerapi_lib.sh:473-505` (`ra_route`):
`/status /usage /cost /bill /balance /clients /live /history /devices /device/rename /device/watch /friday /test /proxy/switch /reboot`.

---

## Summary verdicts (one line per data need)

1. Per-device IP / hostname / online / last-seen — **approximate** (IP+hostname covered; online≈lease-presence proxy; last-seen time is a gap)
2. Per-device monthly usage — **covered** (`/usage?period=month`; past months via `/bill?month=`)
3. Per-device usage history over time (daily/hourly) — **gap** (only monthly sums exposed; app self-records locally)
4. Online/offline history per device — **gap** (nothing stored or exposed)
5. Account-level balance (plan + freshness) — **covered** (`/balance`)
6. Per-package history — **gap** (router serves only current package state; app keeps its own snapshots)
7. Aggregated hourly usage telemetry — **covered** (`/history?kind=usage`)
8. Daily balance history — **covered** (`/history?kind=balance`)
9. Eventing/push for unknown-device joins — **gap** (Telegram-only alert; app polls/diffs)
10. Router health (uptime/load/RAM/temp/disk/proxy) — **covered** (`/status`)
11. Actions (proxy switch, reboot, rename/watch, friday, test) — **covered** (all six exist)

---

## Table

| Data need | Endpoint today | Verdict | Evidence |
|---|---|---|---|
| 1a. Device IP | `GET /clients` → `clients[].ip` | covered | `ra_json_clients` reads `ts mac ip hostname client` from `/tmp/dhcp.leases` (`routerapi_lib.sh:312-324`); DTO `ClientDto.ip` (`Api.kt:82`) |
| 1b. DHCP hostname | `GET /clients` → `clients[].hostname` (and `name` falls back to it) | covered | `routerapi_lib.sh:314-317`; `ClientDto.hostname` (`Api.kt:83`) |
| 1c. Online/offline state | none explicit; app treats “present in `/clients`” as online | approximate | Router has no online flag; presence in `/tmp/dhcp.leases` is a lingering lease. App: `val online = vm.clients…map { it.mac }` and filters `d.mac.lowercase() in online` (`ui/Data.kt:531,549`). `/live` device presence (`rx_bytes/tx_bytes`) is a second recent-activity proxy (`routerapi_lib.sh:328-342`, `ra_nlbw_macs` `:121-123`) but nlbw counters persist, so absence ≠ offline. `devicewatch.sh:9-27` uses lease-presence for its alerts, same coarse notion. |
| 1d. Last-seen time | none | **gap** | `/clients` discards the lease-expiry timestamp (`read -r ts mac …` at `routerapi_lib.sh:312`, `ts` never serialized; `ra_json_clients:309-326`). No `last_seen` anywhere. App stores only `lastSeenName` (a string, not a time) — `DeviceSettingsEntity` (`Db.kt:66-75`). |
| 2. Per-device monthly usage | `GET /usage?period=month` (current month); `GET /bill?month=YYYY-MM` (any past month, rows carry `gb`) | covered | `ra_json_usage month` sums `$RA_USAGE_LOG_DIR/YYYY-MM.log` per key (`routerapi_lib.sh:115-120, 191-208`); `ra_json_bill` prices any `month` (`:254-275`, month param `:488`). App consumes both (`AndroidSnapshotCycleRuntime.kt:27,29`). Note `/usage` has no `month=` param — only `/bill` reaches past months. |
| 3. Per-device usage history over time | none (monthly log is summed; per-day rows exist on-disk but are not exposed) | **gap** | `ra_usage_month_rows` `s[k]+=b` collapses every row of the month to one total per key (`routerapi_lib.sh:115-120`); the log file itself can hold per-day rows `DATE|KEY|BYTES` (`tests/test_usage.sh:19-24`), so per-day data physically exists but no endpoint returns it. `/bill` gives only one point per month. App compensates by recording its own per-day per-device rows in Room on every poll — `LedgerKeeper.recordDaily` (`LedgerKeeper.kt:51-66`, `DailyUsageEntity` `Db.kt:117-122`) — so no backfill before install. |
| 4. Online/offline history per device | none | **gap** | Nothing on the router stores when a MAC was present/absent. `devicewatch.sh` only alerts (Telegram) on new/active MACs (`devicewatch.sh:16-27, 34-64`); it keeps no timeline. App keeps only the latest `deviceMacs` set for diffing (`Notify.kt:15,49,105`); no per-device windows persisted. |
| 5. Account-level balance | `GET /balance` → `data_plan{provider,subscriber,quota_gb,remain_gb,consumed_gb,activation,expiry,status,freshness}` + `packages[]` + `as_of_unix` | covered | `ra_json_balance` (`routerapi_lib.sh:277-307`); aggregate defaults build `data_plan` from the cached report (`:297`); packages come from the `/tmp/samantel_packages.json` projection written by `balance.sh cache_packages` (`balance.sh:89+`), freshness `as_of_unix` from `/tmp/balance_report.ts` (`:281`). Parsed by `hn_balance_fields` (`hnlib.sh:20-36`). DTO `DataPlanDto`/`PackageFreshnessDto` (`Api.kt:48-53`). Caveat: cached (written by `--report/--cache` and `--monitor` every ≤15 min, `balance.sh:376-384`), not live ISP. |
| 6. Per-package history | none (current state only) | **gap** | `/balance` serves today’s `packages[]` + `data_plan` only (`routerapi_lib.sh:292-297`). No per-package time series. App records its own snapshots locally on every ingest — `PackageSnapshotEntity` (`Packages.kt:30-34`), `dao.insertSnapshot` in `PackageSync.sync` (`Packages.kt:173,186,197-199`), read via `vm.packageSnapshots(id)` (`XirouterViewModel.kt:277`); `data_plan`/`series` are aggregate, not per-package. |
| 7. Aggregated hourly usage telemetry | `GET /history?kind=usage&days=N` | covered | `ra_json_history usage` tails the hourly telemetry log `ts|total_gb|…` (`routerapi_lib.sh:358-367`); written hourly by `snap.sh:20` (`date|total_gb|balance|proxy`). App: `AndroidSnapshotCycleRuntime.kt:35-36` (days=30), charted as daily increments (`ChartMath.jalaliMonthDailyUsage`, `ui/Data.kt:143-150`). Value is cumulative total GB — the incrementing is client-side (`ChartMath.cumulativeIncrements:56-68`). |
| 8. Daily balance history | `GET /history?kind=balance&days=N` | covered | `ra_json_history balance` from `ra_balance_series` (last 90 days of `/etc/balance-log/*.log`) (`routerapi_lib.sh:347-356,127-131`); daily rows written by `balance.sh snapshot_history` (`balance.sh:182-194`, called from `set_anchor_from_rows` `:208`). App: `AndroidSnapshotCycleRuntime.kt:37-38` (days=90). |
| 9. Eventing/push for unknown-device joins | none | **gap** | `routerapi.sh` is a request/response CGI dispatcher — no WebSocket/SSE/push channel (`routerapi.sh:19-37`). The router already detects new MACs (`devicewatch.sh:16-27`) but alerts only Telegram (`/root/tg.sh --card`). App diff detects the event on the next poll — `deviceMacs` set diff → `AlertEvent.NewDevice` (`Notify.kt:15,49`); worker runs every 15 min (`Notify.kt:121-131`), so detection is polling-latency-bound and missed entirely while the phone is off-network. |
| 10. Router health | `GET /status` | covered | `ra_json_status` — uptime, load, `ram{used_mb,total_mb}`, `temp_c`, `disk{pct,free}`, `proxy{state,latency_s,node}` (`routerapi_lib.sh:177-187`; state readers `:92-113`). DTO `StatusDto` (`Api.kt:8-20`). |
| 11a. Proxy switch | `POST /proxy/switch` `{node}` | covered | `ra_switch_proxy` → `ra_uci_switch` (`routerapi_lib.sh:452-461,152-159`); app `switchProxy` (`XirouterViewModel.kt:411-416`) |
| 11b. Reboot | `POST /reboot` | covered | `ra_reboot`/`ra_do_reboot` (`routerapi_lib.sh:463-466,160-163`); app `reboot` (`XirouterViewModel.kt:418-423`) |
| 11c. Device rename | `POST /device/rename` `{mac,name}` | covered | `ra_rename_device` (`routerapi_lib.sh:401-414`); app `renameDevice` (`XirouterViewModel.kt:289-298`) |
| 11d. Device watch | `POST /device/watch` `{mac,on}` | covered | `ra_watch_device` (`routerapi_lib.sh:416-428`); app `setWatch` (`XirouterViewModel.kt:279-287`) |
| 11e. Friday flag | `POST /friday` `{friday}` | covered | `ra_set_friday` writes `LAST_FRIDAY` (`routerapi_lib.sh:430-440`); app `/friday` not wired in the ViewModel but endpoint exists and is documented (`API_CONTRACT.md:174-177`) |
| 11f. URL test | `POST /test` `{url}` | covered | `ra_test_url` → `ra_url_test` (`routerapi_lib.sh:442-450,132-134`); app `testUrl` (`XirouterViewModel.kt:404-409`) |

## Cross-cutting notes

- **Auth** — Basic auth, token as password, username fixed `xirouter`: `ra_authed` (`routerapi_lib.sh:74-89`) accepts `Authorization: Basic base64(xirouter:<token>)` (and legacy `X-Router-Token` header for back-compat). App sends exactly that (`ApiClient.kt:51-53`). 401 → `{"error":"unauthorized"}` (`routerapi_lib.sh:480-482`).
- **JSON responses** — `routerapi.sh:24` sets `Content-Type: application/json`; non-200 adds `Status:` with a reason phrase (`routerapi.sh:25-35`). All builders emit the documented shapes; unit tests pin them (`tests/test_status.sh`, `test_usage.sh`, `test_cost.sh`, `test_bill.sh`, `test_balance.sh`, `test_clients.sh`, `test_devices.sh`, `test_live.sh`, `test_history.sh`).
- **Contract parity** — every endpoint in `ra_route` (`routerapi_lib.sh:484-501`) is documented in `API_CONTRACT.md`; there are **no undocumented router endpoints** and no stale contract entries. The app copy is current (both files dated 13 Aug).
- **`/balance` freshness caveat** — values are cached ISP reads; `data_plan.freshness.as_of_unix` and top-level `as_of_unix` are the report-cache write time, refreshed at most every ~15 min by `--monitor` (`balance.sh:376-384`), not a live ISP query. The app already surfaces this (“آفلاین؛ نمایش آخرین موجودی دریافتشده”, `ui/Data.kt:276`).

---

## New endpoints worth considering (true gaps)

Only gaps the app cannot close on its own are listed. Each is named as the router would implement it.

- **`GET /devices/history?mac=&days=`** — per-device daily usage history for trend charts (need #3). The app cannot approximate: its local `daily_usage` recorder (`LedgerKeeper.recordDaily`) only starts at install/first poll, so pre-install history is unrecoverable client-side. The router already has the raw per-day rows in `/etc/usage-log/YYYY-MM.log` (`tests/test_usage.sh:19-24`); the endpoint would expose them instead of summing them away (`ra_usage_month_rows`, `routerapi_lib.sh:115-120`). Note the writer `/root/usage.sh` is not in this repo, so the row format must be pinned before exposing.
- **`GET /devices/activity?mac=` (or add `last_seen_ts`/`lease_expiry` to `/clients`)** — online/offline state and last-seen time (needs #1d, #4). The lease-expiry timestamp is already read from `/tmp/dhcp.leases` and discarded (`routerapi_lib.sh:312`); exposing it (or a richer per-MAC nlbw activity timestamp) gives the app a real last-seen without any new capture. True per-device online/offline *history* would need a new store (e.g. a `devicewatch`-style presence log appended on each alert pass, `devicewatch.sh:16-27`).
- **`GET /packages/history?package_id=&days=`** — per-package balance history (need #6). The app’s `PackageSnapshotEntity` store (`Packages.kt:30-34`) only exists from install onward; the router could snapshot `packages[]` alongside the existing daily balance snapshot (`balance.sh snapshot_history:182-194`) and serve the series. Client-side approximation cannot fill pre-install gaps.
- **`GET /events` (new-device/state-change event log, consumed by the poller)** — push-like eventing for unknown-device joins (need #9). The router already *computes* the event (`devicewatch.sh:16-27`) but only knows Telegram; there is no push channel (`routerapi.sh` is request/response). An event log file the app reads (e.g. `/tmp/router-events.log` appended by `devicewatch`, exposed with an `after_id` cursor) would let the app catch joins missed while the worker wasn’t running, removing the 15-minute diff latency (`Notify.kt:121-131`) and the poll-diff race (`Notify.kt:49`).

Note: needs #2, #5, #7, #8, #10, #11 are fully covered today and need no new endpoints.
