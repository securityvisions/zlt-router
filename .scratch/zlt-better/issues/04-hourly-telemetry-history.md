# 04 — Hourly telemetry + history

**What to build:** Extend `Telemetry log` (`ts|total_gb|balance_gb|proxy_state|operator|rsrp|temp|load`) hourly via `procd`; feeds app charts and the cost/bill history the `Router API` and `x28-usage.sh` already read.

**Blocked by:** 01 — Thermal guard + overheat alert.

**Status:** resolved

- [x] `x28-telemetry.sh` appends one row per hour (ts, modem WAN totals, temp, load, Link operator/rsrp, mihomo auto-now, usage total) to `Telemetry log` on `/data`.
- [x] Survives reboot (procd, boot-enabled); 24h run shows 24 rows with sane values; health gate GREEN.
- [x] Existing `x28-usage.sh` weekly/monthly aggregations can read it (no breakage).
