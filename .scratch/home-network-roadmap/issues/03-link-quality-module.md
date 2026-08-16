# 03 — Link-quality measurement module

**What to build:** The router answers "how good is the link right now", not just "is it alive". A shared module measures three signals: cheap latency through the current node, passive throughput derived from the hourly telemetry `total_gb` deltas (free — no extra bandwidth), and a targeted small throughput sample fired only on suspicion of degradation. A pure decision maps those to healthy / degraded. This is the data layer every resilience feature consumes.

**Blocked by:** None — can start immediately.

**Status:** resolved (link-quality module: latency/passive/sample/decision + tests)

- [ ] Latency reuses the existing `generate_204` probe through the SOCKS port.
- [ ] Passive Mbps is derived from hourly telemetry deltas; pure and fixture-tested.
- [ ] Targeted sample reuses the speedtest seams with an env-tunable size.
- [ ] The healthy/degraded decision is a pure function with an env-tunable floor, default 10 Mbps; fixture-tested.
- [ ] On the router, the module prints the current link quality.
