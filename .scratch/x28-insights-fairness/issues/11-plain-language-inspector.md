# 11 — Plain-language activity inspector

**What to build:** A live view of what the network is actually doing, in sentences anyone can read: "parsa — YouTube, ~30 min, ~400 MB", "baba — Steam download, active now". Built on the proxy engine's local connections API mapped through device→person attribution. Powerful enough to feel invasive, so it ships privacy-first: full detail for the admin only; everyone else sees masked/aggregated summaries (or nothing, per a visible toggle).

**Blocked by:** 01 — Restore point.

**Status:** ready-for-agent

- [ ] Live activity feed renders human-readable sentences (person + app/site + rough volume), refreshed continuously
- [ ] Privacy default: admin sees full detail; non-admin viewers get masked/aggregated output or an explicitly-off state
- [ ] Attribution reuses the shared owner seam — no parallel person mapping
- [ ] Feed degrades gracefully when the connections API is unavailable
- [ ] Deploys via targeted pushes only; proxy engine untouched (read-only API consumption)
