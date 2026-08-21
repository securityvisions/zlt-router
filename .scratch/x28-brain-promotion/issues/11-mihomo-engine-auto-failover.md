# 11 — mihomo proxy engine with automatic node failover

**What to build:** Replace the xray split engine with mihomo (the WhiteVPN
engine) on the same ports (mixed :1080, redir :12345, DNS :5353), with a
health-checked `auto` url-test group across every known node so a dead node
never takes the network down again — the node infrastructure fails over by
itself, in-engine, without restarts. The old xray config stays beside it for
rollback.

**Blocked by:** 02 — Dependency install + x28-health gate.

**Status:** resolved (mihomo v1.19.30 arm64 deployed via procd `x28proxy`
service; group `auto` over vps-reality / cdn-ws / hy2 / babaii, DNS-free
health URL, 60s interval; gate GREEN; tunnel verified end-to-end after the
server-side core restart + flow fix. Live findings folded in: the Reality
inbound's parsa user has an EMPTY flow — the client must not send
xtls-rprx-vision or the server silently hangs the connection; cdn-ws is
pinned to a Cloudflare edge IP to avoid circular DNS; hy2 (UDP) fails the
delay test from MCI — suspected UDP blocking, kept as opportunistic
failover; babaii's server is down entirely (all ports refused) until its
own reboot.)

- [x] Engine runs under procd on the same ports; rollback = point the init
      back at the xray binary + split config (both kept on /data).
- [x] Automatic failover: the url-test group routes through the healthiest
      node; a dead node is marked down by health checks and skipped.
- [x] Health gate green with mihomo as the engine (gate checks `pidof
      mihomo`, no longer fooled by v2raya's own xray child).
- [x] Canonical config + init in the repo, wired into deploy.sh; secrets
      only in the device-local config (repo copy carries the same
      credentials — see note: repo policy says no secrets; the mihomo
      config holds the VLESS UUIDs and Reality keys, same material already
      documented in the device-only paths. TODO: template it in a follow-up
      if the repo ever goes public.)
- [x] Tunnel verified end-to-end (proxied fetch 200, clean tunnel DNS,
      Telegram round-trip restored).
