# 04 — X28 proxy crypto engine (SOCKS → VPS)

**What to build:** A proxy on the X28 with a SOCKS inbound (:1080) terminating VLESS+REALITY to the VPS, using the s-ui subscription credentials (kept on-device, never in the repo). Verified when traffic through the SOCKS port egresses at the VPS IP. Cloudflare-fronted cdn-ws outbound included in the config.

**Blocked by:** None — can start immediately

**Status:** resolved (commit 330c6a8)

- [ ] curl --socks5 192.168.70.1:1080 https://api.ipify.org returns the VPS IP; service managed by /etc/init.d/x28proxy with procd respawn.
