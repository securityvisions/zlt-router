# 01 — Per-node ping with inline latency

**What to build:** Every proxy node row in the dashboard gets a ping button (active node included). Pressing it probes latency through that node and shows the result inline — `xx ms` or `✗` — in a new latency column, instead of a browser alert. The last-known latency survives the 30s auto-refresh until re-pinged.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [x] Proxy management CGI gains an env seam for the mihomo controller URL (fixture-testable)
- [x] Fixture test with a stubbed controller: single-node delay probe returns the expected latency; a dead node returns the error path
- [x] Dashboard proxy table gains a latency column
- [x] Each node row (including the active one) has a ping button that probes and renders ms/✗ inline — no alert
- [x] Last ping result is remembered across the 30s auto-refresh until re-pinged