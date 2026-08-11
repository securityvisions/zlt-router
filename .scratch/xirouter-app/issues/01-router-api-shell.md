# 01 — Router API shell + auth

**What to build:** The router speaks authenticated JSON over HTTP. A token in a root-only config, a uhttpd CGI dispatcher checking it, JSON/error helpers, a Status endpoint (uptime, load, RAM, temp, disk, active proxy node + latency), the ADR recording the choice (uhttpd CGI + shared token), and the API contract seeded. Verified with curl from the LAN: 401 without the token, JSON with it.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] 401 without the token, JSON with it, for every endpoint
- [ ] /status returns the documented JSON shape from real router state
- [ ] ADR-0002 and the API contract exist and match the implementation
