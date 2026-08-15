# 08 — Cloudflare Tunnel for remote app access

**What to build:** cloudflared on the AX3000T exposes the Router API (token-gated, HTTPS) through a Cloudflare Tunnel so the Xirouter app works from anywhere — replacing the plain-WireGuard plan that is unreliable in Iran.

**Blocked by:** None — can start immediately

**Status:** in-progress (cloudflared-setup.sh + init delivered; needs user Cloudflare credentials for live tunnel)

- [ ] The Xirouter app loads live data from a remote network via the tunnel URL.
