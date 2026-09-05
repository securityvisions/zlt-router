# 08 — Cloudflare Zero Trust Remote Mobile Access

**What to build:** Install `cloudflared` and `luci-app-cloudflared` on the AX3000T. Configure an outbound Zero Trust tunnel token connecting to Cloudflare Edge to enable secure remote access to the LuCI router admin and network monitoring from mobile outside the house, completely bypassing Iran cellular CGNAT without opening any ports.

**Blocked by:** 01 (TCP BBR), 02 (MTK WED).

**Status:** wontfix

## Decision & Cleanup

- **Explicitly Rejected:** Cloudflare Zero Trust tunnel removed per user request. Not needed for this home network.
- **Cleanup Completed:**
  - AX3000T: Verified `cloudflared` is not installed on the router; overlay storage preserved.
  - X28: Stopped and removed legacy `/etc/init.d/x28-tunnel` procd service and killed background looping process. Removed `/data/proxy/x28-tunnel*` artifacts. Zero processes running.
  - Zero open incoming WAN ports, zero external tunnel dependencies.
