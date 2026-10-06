# 02 - Prune Dead Nodes and Harden sing-box urltest

Status: resolved
Assignee: agent
Type: task

## Answer

1. **Root Cause Confirmed:**
   - In AX3000T's `/etc/sing-box/config.json`, the `auto` outbound group was configured as a `urltest` including 4 nodes: `["vps-reality", "hy2", "via-x28", "cdn-ws"]`.
   - `hy2` (port 31800 UDP) and `cdn-ws` (188.114.98.0:443) are completely filtered/dead on the current cellular uplink.
   - During urltest cycles and DoH exchanges (`detour: auto`), attempting to dial these dead nodes resulted in 5-second hangs, socket contention, and `outbound/urltest[auto]: dial tcp 85.121.124.158:443: i/o timeout` + `context deadline exceeded`.
   - Additionally, `interrupt_exist_connections: true` was missing, meaning stalled sockets were held open rather than severed immediately upon node switching.
2. **Resolution Applied:**
   - Pruned dead nodes from `auto`: `auto` now only tests verified live nodes: `vps-reality` (primary direct VPS tunnel, 307ms) and `via-x28` (backup SOCKS5 to X28 Mihomo + rescue pool, 950ms).
   - Retained `hy2` and `cdn-ws` in `proxy-select` for optional manual selection.
   - Configured `interval: "30s"`, `tolerance: 50`, and `interrupt_exist_connections: true`.
   - Deployed and restarted sing-box with zero downtime.
   - Verified that `auto` resolves in 307ms, `vps-reality` is permanently active, and watchdog probe passes with `FAILS=0`.
Blocked by: none

## Question

Why did `sing-box` log multiple `outbound/urltest[auto]: dial tcp 85.121.124.158:443: i/o timeout` and DoH context deadline exceeded errors, and how should `/etc/sing-box/config.json` `auto` outbound be hardened?

### Findings & Context

1. Outbounds in `auto`:
   - `vps-reality` (ALIVE, delay: 330ms)
   - `via-x28` (ALIVE, delay: 950ms)
   - `hy2` (DEAD, port 31800 UDP dropped by cellular network, delay: Timeout)
   - `cdn-ws` (DEAD, 188.114.98.0:443, delay: Timeout)
2. Half the nodes in `auto` are dead. During 60-second urltest cycles, probing dead nodes causes pipeline stalls and socket exhaustion.
3. `interrupt_exist_connections: true` is missing, preventing fast disconnection of hung sockets.
4. `auto` should contain only verified live nodes (`vps-reality` and `via-x28`), or fall back cleanly.
