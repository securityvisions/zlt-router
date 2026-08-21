# 05 — Cloudflare Tunnel remote access

**What to build:** `cloudflared` on `X28` exposes `192.168.70.1` via Tunnel — `Xirouter app` works outside home without opening ports (no plain WireGuard in Iran per `ARCHITECTURE.md`); health visible in `Telemetry log`.

**Blocked by:** 04 — Hourly telemetry + history.

**Status:** resolved

- [x] `cloudflared` binary + `x28-tunnel.init` procd service running, tunnel `trycloudflare` or named, health URL reachable.
- [x] Remote `curl` via tunnel returns `Router API` status (or admin page) with token auth; health gate GREEN; no firewall hole opened.
- [x] Documented in `OPERATIONS.md` + `router/x28/README.md` (tunnel ID/token lives only in `/etc/tunnel.conf` on device).
