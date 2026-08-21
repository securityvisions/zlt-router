# 04 — DHCP DNS single-source lock

**What to build:** `dns-fix.sh` permanently strips the vendor secondary `114.114.114.114` from `dhcp-option=br0,option:dns-server` so clients (e.g., `ZL-5G` `192.168.70.141`) only get `192.168.70.1` — poisoned `10.10.34.35` for `youtube.com` can no longer win the race.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [x] `grep dhcp-option.*dns-server /tmp/dnsmasq.conf` shows only `192.168.70.1` after `dns-fix.sh` and after a `lan_mgr` regeneration + hotplug re-apply.
- [x] `nslookup youtube.com` from a `192.168.70.0/24` client returns `142.251.x.x` (clean) and `youtube 200` via `mihomo` `auto`.
- [x] Documented in `router/x28/README.md` and `docs/OPERATIONS.md` (no firewall hole).
