# 02 — hy2 UDP keep-alive (opportunistic)

**What to build:** `hy2` (Hysteria2 `85.121.124.158:31800` salamander) stays as opportunistic failover in `mihomo` `auto` — marked alive when UDP to the VPS is not throttled (MCI often blocks QUIC/UDP), skipped otherwise, never blocks the house.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] `hy2` delay probe via `auto` group succeeds on at least one ISP or is correctly marked down; no false alive.
- [ ] `mihomo` log shows `hy2` UDP dial attempts without crashing the service; `HEALTH: GREEN` after deploy.
