# 08 — Cloudflare Zero Trust Remote Mobile Access

**What to build:** Install `cloudflared` and `luci-app-cloudflared` on the AX3000T. Configure an outbound Zero Trust tunnel token connecting to Cloudflare Edge to enable secure remote access to the LuCI router admin and network monitoring from mobile outside the house, completely bypassing Iran cellular CGNAT without opening any ports.

**Blocked by:** 01 (TCP BBR), 02 (MTK WED).

**Status:** ready-for-agent

## Implementation Details

- Packages: `cloudflared` and `luci-app-cloudflared` (available in official 25.12.5 feed).
- Architecture:
  - Tunnel initiates outbound connection to Cloudflare Edge (never requires incoming ports or public IP).
  - Web service mapped to `http://localhost:80` (LuCI).
  - Gated behind Cloudflare Zero Trust Access policy (One-Time PIN or Google OAuth).
- Configuration:
  - `/etc/config/cloudflared`:
    ```uci
    config cloudflared 'global'
        option enabled '1'
        option token '<CLOUDFLARE_TUNNEL_TOKEN>'
    ```
  - Procd supervision handles automatic reconnection and backoff across WAN dropouts.

## Verification Criteria

- [ ] `ps | grep cloudflared` confirms daemon is running.
- [ ] LuCI displays `Services -> Cloudflare Tunnel` status page.
- [ ] Accessing configured subdomain from external mobile device (on cellular data) prompts for Cloudflare Access auth.
- [ ] Authenticated user can securely view LuCI web admin and router health.
- [ ] No incoming ports opened in firewall (`nftables` input remains drop/reject).
- [ ] Memory footprint check: <15 MB RAM.
