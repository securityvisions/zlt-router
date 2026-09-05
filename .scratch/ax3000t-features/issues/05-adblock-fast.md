# 05 — Network-Wide Lightweight Ad & Tracker Blocking

**What to build:** Install `adblock-fast` and `luci-app-adblock-fast` on the AX3000T. Configure compact, high-reputation domain blocklists (OISD / StevenBlack) integrated directly into `dnsmasq` with an automated weekly update cron. Blocks mobile in-app ads, telemetry, scam domains, and trackers across all devices on `XI-5G` and `XI-2G`.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

## Implementation Details

- Packages: `adblock-fast` and `luci-app-adblock-fast` from official feed.
- Configuration: `/etc/config/adblock-fast`:
  - Output format: dnsmasq format (`/var/run/adblock-fast/adblock-fast.dnsmasq`).
  - Sources: compact high-impact sources (`adguard`, `oisd_basic`, `stevenblack`).
  - Memory safety: restrict max domains to 35,000 (~3 MB RAM footprint) to ensure plenty of headroom.
  - Automatic cron: updates once a week at 04:00.
- Integration: dnsmasq automatically loads the blocklist file.

## Verification Criteria

- [ ] `adblock-fast status` returns running with active blocked domain count (>20,000 domains).
- [ ] LuCI displays `Services -> AdBlocking-Fast` management page with toggle and statistics.
- [ ] Visiting known ad/telemetry test domains (e.g. `doubleclick.net`, `adservice.google.com`) returns `NXDOMAIN` or `0.0.0.0`.
- [ ] Domestic banking and essential services remain completely unblocked (whitelist clean).
- [ ] Memory footprint check: <5 MB RAM used by dnsmasq.
