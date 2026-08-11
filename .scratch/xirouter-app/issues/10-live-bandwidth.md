# 10 — Live bandwidth

**What to build:** A router Live endpoint returning cumulative per-MAC totals (cheap), and the app's Live screen diffing ~1 s apart to show per-device + total throughput. Start a download and the app names the device eating it.

**Blocked by:** 01, 02

**Status:** ready-for-agent

- [ ] /live returns cumulative per-MAC + WAN counters
- [ ] Live screen shows per-device and total up/down rates
- [ ] Rate math is unit-tested
