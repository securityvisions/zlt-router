# 03 — Bring the VLESS REALITY proxy back online with unchanged credentials

**What to build:** The VLESS+REALITY inbound on 443 with the exact same private key, short ID, `www.bing.com` target/SNI, and existing clients (including traffic caps). The router's PassWall node reconnects and egresses through the VPS again, and the URLTest auto-failover re-selects VLESS — all verified end-to-end with no client reconfiguration.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] The VLESS+REALITY inbound exists on 443 with the preserved private key, short ID, target, and all three clients including their traffic caps
- [ ] The router's PassWall node passes its standalone connectivity test (returns 200)
- [ ] Traffic through the router's proxy egresses via the VPS IP
- [ ] The URLTest auto-failover re-selects the VLESS node automatically
