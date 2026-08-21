# 02 — cdn-ws origin fix

**What to build:** `cdn-ws` (`cdn.dmbz.ir`) stops `Timeout` — Cloudflare edge `188.114.98.0:443` correctly hits origin `:8443` (or direct `85.121.124.158:8443` if MCI blocks Cloudflare). `delay` becomes healthy and `youtube 200` stays via `auto` even if `vps-reality` dies.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [x] `mihomo` `cdn-ws` `delay` probe via `auto` becomes healthy (non-timeout) and `youtube 200` via `cdn-ws` alone succeeds.
- [x] `HEALTH: GREEN` after deploy; no secrets in repo.
