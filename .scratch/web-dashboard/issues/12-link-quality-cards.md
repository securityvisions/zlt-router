# 12 — Dashboard: link + quality cards

**What to build:** The X28 cellular link card (operator/tech/signal/RSRP/PLMN/flow) from `/link`, and the hourly link-quality chart (passive throughput bars + latency line) from `/quality`, rendered dependency-free with SVG.

**Blocked by:** 08, 09

**Status:** ready-for-agent

- [ ] LinkCard renders the X28 link state; loading/error states handled.
- [ ] QualityChart renders bars + latency line for the last 24h; empty state handled.
