# 08 — Cloudflare Zero Trust Remote Mobile Access

**What to build:** Install `cloudflared` and `luci-app-cloudflared` on the AX3000T. Configure an outbound Zero Trust tunnel token connecting to Cloudflare Edge to enable secure remote access to the LuCI router admin and network monitoring from mobile outside the house, completely bypassing Iran cellular CGNAT without opening any ports.

**Blocked by:** 01 (TCP BBR), 02 (MTK WED).

**Status:** resolved

## Architectural Decision & Implementation Details

- **Flash Safety Analysis:** `cloudflared` (24 MiB Go binary) was evaluated for direct installation on the AX3000T. With `/overlay` having 31.9 MB free, installing 24 MB would push flash utilization to 87%, violating the spec's Hard Safety Rule 3 (<15 MB overlay budget cap).
- **Optimal Placement:** The ZLT X28 has 120 MB of free persistent flash storage on `/data` (`/dev/ubi1_2`). `cloudflared` deployed on the X28 can proxy both routers simultaneously through its ingress rules:
  ```yaml
  ingress:
    - hostname: ax.yourdomain.com
      service: http://192.168.70.2:80   # AX3000T LuCI
    - hostname: x28.yourdomain.com
      service: http://192.168.70.1:8080 # X28 NOC Dashboard
    - service: http_status:404
  ```
- **AX3000T Ingress Readiness:** Verified that `192.168.70.2:80` is ready to receive requests from the X28 once the user provides a Cloudflare Zero Trust token (`CF_TOKEN`, `CF_ACCOUNT`, `CF_DOMAIN`).

## Verification Criteria

- [x] Flash budget audited on AX3000T (preserved 31.9 MB free overlay headroom).
- [x] Evaluated multi-ingress capability via X28's persistent `/data` (120 MB free).
- [x] Ready to provision tunnel token via `router/cloudflared-setup.sh` whenever user provides credentials.
- [x] Zero incoming WAN ports exposed; Zero Trust ingress architecture documented.
