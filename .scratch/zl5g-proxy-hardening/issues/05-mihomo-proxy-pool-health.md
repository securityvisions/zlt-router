# 05 - Rebalance Mihomo Node Pool & Latency Selection

Status: resolved
Assignee: agent
Type: task

## Answer

1. **Root Cause Confirmed:**
   - Group `auto` was testing `https://8.8.8.8/` which returns HTTP 302 redirects, rather than a standard HTTP 204 endpoint.
   - Group `world` was set to static `type: select`, meaning that if `auto` died, internet traffic dropped completely instead of autonomously falling back to the 46 active nodes in `rescue-pool`.
   - Out of the 4 nodes in `auto`, `vps-reality` is healthy and stable (769ms delay), while `cdn-ws` and `babaii` are dead. `hy2` UDP packets are currently filtered on this cellular route to port 31800.
2. **Resolution Applied:**
   - Updated `auto` health-check test URL to standard `https://www.gstatic.com/generate_204`.
   - Changed `world` proxy group from static `select` to autonomous `fallback` (`type: fallback`, `url: https://www.gstatic.com/generate_204`). If `auto` becomes unresponsive, `world` automatically falls back to `rescue` pool.
   - Reloaded Mihomo configuration in-memory without downtime.
   - Synced template in `router/x28/mihomo-config.yaml`.
Blocked by: none

## Question

How should dead nodes (`cdn-ws`, `babaii`) and the pinned `vps-reality` node in Mihomo's `auto` group be reconfigured so traffic automatically flows through the lowest-latency healthy tunnel (`hy2` at ~317ms)?

### Findings & Context

Querying `http://127.0.0.1:9090/proxies` shows:
- `cdn-ws`: `alive: false` (delay: 0, dead)
- `babaii`: `alive: false` (delay: 0, dead)
- `vps-reality`: `alive: true`, delay: ~967ms, and group `auto` has `"fixed": "vps-reality"`.
- `hy2`: `alive: true`, delay: ~317ms, but not selected as active.
All outbound proxied traffic from X28 is currently forced through high-latency (967ms) REALITY instead of Hysteria2 (317ms).
