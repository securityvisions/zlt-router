# 02 — Debrid-backed playback (Real-Debrid + Torrentio)

**What to build:** P2P playback is structurally unworkable on this network
(peers refuse the VPS datacenter IP; uTP/DHT UDP filtered by carrier — evidence
on 01). Switch Torrentio to debrid mode so streams become plain HTTPS CDN
downloads that ride the existing tunnel. User-side actions: RD account + API
key, configure torrentio.strem.fun/configurations with Real-Debrid, reinstall
personalized addon, TV resyncs via account.

**Blocked by:** 01 (resolved).

**Status:** ready-for-human

- [ ] Real-Debrid account funded (crypto route) + API key obtained
- [ ] Torrentio reconfigured with RD on phone/PC, personalized addon installed
- [ ] Phone/PC: stream list instant, playback works
- [ ] TV: same movie plays after account resync
