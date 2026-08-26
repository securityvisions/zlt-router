# 01 — Torrentio stream list never loads on the TV

**What to build:** Stremio on the Tizen TV (192.168.70.155) spins forever on
Torrentio's stream list. Root cause found live 2026-08-26: the addon domain is
Cloudflare-fronted and returns HTTP 403 to the VPS datacenter IP while
answering 200 directly from the carrier — the LAN-wide "foreign traffic rides
the tunnel" policy broke exactly this domain. Fix: one DIRECT rule above the
general rules so *.strem.fun egresses direct.

**Blocked by:** None.

**Status:** resolved

- [x] Evidence matrix recorded (tunnel=403/direct=200 for torrentio.strem.fun; cinemeta/api/opensubtitles indifferent)
- [x] `DOMAIN-SUFFIX,strem.fun,DIRECT` inserted in live config above GEOSITE rules + hot-reload (HTTP 204, no engine restart)
- [x] Verified: same stream-API request through the LAN path now 200 (~1.2 s)
- [x] Rule mirrored in repo config template for rebuild parity
- [x] Human test on TV: stream list appears (user clicks qualities) — playback is a separate failure, see 02

## Answer

Live-config backup taken before the edit (config.yaml.bak-stremio on device).
First insertion attempt silently no-op'd — sed anchored an unindented pattern
against a two-space-indented rule list; fixed by line-anchored insert at the
GEOIP,IR rule. BitTorrent TCP peers from the TV were observed healthy via the
tunnel during diagnosis (port 6881 flows); if the list appears but playback
stalls, the follow-up options are per-device tunnel routing or a debrid
service.

## Comments

> 2026-08-26 — playback phase diagnosed: TV clicks a quality → "can't stream". Evidence: zero payload bytes on every TV peer flow (all ~5-packet dead handshakes via tunnel); differential probes against the exact peers ambiguous but pointless — peers refuse the VPS datacenter IP and uTP/DHT rides the carrier raw (known-filtered international UDP). Conclusion: P2P is structurally unworkable on this network shape; routing tricks (per-device UDP tunnel) would still fail and endanger the VPS (copyright abuse). Recommendation: Real-Debrid/AllDebrid + Torrentio debrid mode — verified both services answer 200 on tunnel AND direct paths. Steps handed to user.
