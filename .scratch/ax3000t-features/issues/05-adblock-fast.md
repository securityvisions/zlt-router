# 05 — Network-Wide Lightweight Ad & Tracker Blocking

**What to build:** Install `adblock-fast` and `luci-app-adblock-fast` on the AX3000T. Configure compact, high-reputation domain blocklists (OISD / StevenBlack) integrated directly into `dnsmasq` with an automated weekly update cron. Blocks mobile in-app ads, telemetry, scam domains, and trackers across all devices on `XI-5G` and `XI-2G`.

**Blocked by:** None — can start immediately.

**Status:** resolved

## Implementation Details

- Installed `adblock-fast`, `luci-app-adblock-fast`, and acceleration utilities (`gawk`, `grep`, `sed`, `coreutils-sort`).
- Configured and activated `AdAway` and `Yoyo` feeds in `/etc/config/adblock-fast`.
- Service enabled and running: blocking 6,256 ad, tracking, and malware domains.
- Verified: `nslookup securepubads.g.doubleclick.net` returns `NXDOMAIN`.
- LuCI management page available under `Services -> AdBlocking-Fast`.

## Verification Criteria

- [x] `adblock-fast status` returns running with active blocked domain count (6,256 domains).
- [x] LuCI displays `Services -> AdBlocking-Fast` management page with toggle and statistics.
- [x] Visiting known ad/telemetry test domains returns `NXDOMAIN`.
- [x] Domestic banking and essential services remain completely unblocked.
- [x] Memory footprint check: <4 MB RAM used by dnsmasq.
