# 01 — cdn-ws origin port (188.114.98.0 pin vs :8443)

**What to build:** `mihomo` `cdn-ws` (VLESS+WS via `cdn.dmbz.ir`) stops timing out — Cloudflare edge `188.114.98.0:443` correctly hits origin `:8443` (the `cdn-ws` inbound in `singbox-config:8443`), verified by `delay` probe and `youtube 200` via the `auto` group failover path.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] Origin IP/port for `cdn-ws` verified (panel `cdn-ws` inbound `:8443` vs Cloudflare edge `:443`); `mihomo-config.yaml` pinned accordingly.
- [ ] `curl -x socks5h://192.168.70.1:1080 https://www.youtube.com/` via `cdn-ws` alone returns 200; `auto` group delay for `cdn-ws` becomes healthy.
- [ ] Health gate stays GREEN; no secrets in repo.
