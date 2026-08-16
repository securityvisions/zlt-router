# 09 — Cloudflare tunnel activation

**What to build:** The router becomes reachable from outside via the Cloudflare tunnel — `cloudflared-setup.sh` and its init are already delivered; this ticket runs the setup, brings the tunnel live, and verifies remote reachability. The app can then load live data remotely through the tunnel URL.

**Blocked by:** None — but gated on the user supplying Cloudflare credentials. This is the only human gate in the whole plan; the ticket is buildable the moment credentials exist.

**Status:** open (blocked: user Cloudflare credentials)

- [ ] Tunnel is live once credentials are supplied; the setup script is verified end-to-end.
- [ ] Remote reachability verified from outside the LAN.
- [ ] Optional: the app remote-loads via the tunnel URL.
