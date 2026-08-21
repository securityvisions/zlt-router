# 04 — Balance + Bill with gauges

**What to build:** `Samantel` `Data plan` + `Package` cards via `balance.sh:1` `cache_packages` + `hnlib.sh:hn_cost_table` — `balance_body` gauge `▰▰▰▱` + expiry + `drain` sparkline, `Bill` monthly `TOTAL` with `Toman` `RATE_FULL/FRIDAY` — both as Cards, not lines.

**Blocked by:** 01 — Panel framework + beautiful Card seam

**Status:** resolved

- [x] `Balance` card shows `balance_body` gauge + `Plan` + `Trend` sparkline + `Drain` from `Telemetry log` + per-`Package` rows via `cache_packages`.
- [x] `Bill` card shows `hn_cost_table` monthly `TOTAL` + per-device rows + Friday `RATE_FRIDAY` badge.
- [x] Both cards share the `Panel` keyboard.
