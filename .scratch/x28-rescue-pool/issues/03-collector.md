# 03 — Collector deploy (tunnel-gated, cached)

**What to build:** Fetcher for public configs from the vendored Telegram channel list (t.me/s web previews via curl through the tunnel), merged+deduped into `/data/proxy/rescue/raw/collected.txt` (cap 300). Runs on a 6 h age-gate inside the rescue procd loop and ONLY when DNS is in tunnel mode. Implementation is an auditable POSIX-sh scraper (curl+grep) rather than the upstream Go binary: no toolchain assumption, smaller untrusted surface, identical output contract — rationale recorded.

**Blocked by:** 02.

**Status:** ready-for-agent

- [ ] Vendored channel list committed; fetch goes through SOCKS; ISP-mode ⇒ logged skip
- [ ] Raw cache grows monotonically, dedupes, capped at 300 lines
- [ ] Network failures leave previous cache intact
