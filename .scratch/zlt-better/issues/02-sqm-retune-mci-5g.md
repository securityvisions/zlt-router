# 02 — SQM retune for MCI 5G

**What to build:** Measure `Link` (MCI down/up via speedtest) and set CAKE `down/up` shaped to ~85% of measured, verified by bufferbloat drop — `Link` stays fast without bloating latency for the house.

**Blocked by:** 01 — Thermal guard + overheat alert.

**Status:** resolved

- [x] `x28-sqm.sh` probes `Link` speed (3 samples, median) and writes CAKE qdisc on the WAN (`ccmni1`) with the 85% shape; dry-run flag only prints what it would do.
- [x] Before/after speedtest shows bloat drop (or at least no regression); `Link` throughput stays >80% of unshaped.
- [x] Procd/Cron re-check weekly; health gate GREEN after deploy.
