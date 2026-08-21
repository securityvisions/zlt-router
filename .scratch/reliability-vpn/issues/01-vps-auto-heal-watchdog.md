# 01 — VPS auto-heal watchdog

**What to build:** When `auto` has no alive node for 10 min (while `192.168.70.1:5353` still answers), `X28` logs into `85.121.124.158:2095` (`suiadmin`) and `POST /app/api/restartSb` — the 01:00 hang that needed manual VNC restart would have self-fixed at 01:10.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [x] `x28-vps-heal.sh` polls `mihomo` `auto` health via `127.0.0.1:9090`; after 10 min all-dead, logs in (form-encoded) and restarts sing-box, logs result.
- [x] No restart when tunnel is healthy or when `192.168.70.1:5353` is down (local DNS dead — don't touch VPS).
- [x] Procd service `x28-vps-heal` with `respawn`, `HEALTH: GREEN` after deploy.
