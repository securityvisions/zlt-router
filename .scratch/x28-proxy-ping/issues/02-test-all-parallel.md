# 02 — Working "test all" — parallel ping=all

**What to build:** The proxy card's "test all" button (currently broken — it just reloads the list) pings every node in one action. The CGI fires a delay probe per node in parallel and returns all results in a single round-trip; the dashboard fills every node's latency cell at once, showing dead nodes as ✗ alongside live ones.

**Blocked by:** 01 — Per-node ping with inline latency (same files; reuses the controller seam, stub-curl fixture pattern, and latency column).

**Status:** resolved

- [x] Proxy management CGI gains a ping=all action: probes every auto-group member in parallel, returns per-node name + delay
- [x] Fixture test: ping=all returns the expected latencies for all stubbed nodes, including the dead-node error case
- [x] "test all" button fills every row's latency cell in one action
- [x] Live verification: real latencies returned for the production nodes