# 10 — Fail-open network path (dead VPS must not take the house down)

**What to build:** When the proxy origin (VPS) is unreachable, the X28's
transparent proxy must fail OPEN: LAN traffic flows direct instead of being
redirected into a black-holed tunnel, and DNS falls back to the ISP
resolvers. When the VPS recovers, the tunnel path (split routing + clean
DNS) restores itself with no manual step. The house never loses plain
internet because the proxy origin died — the resilience concept the
AX3000T's PassWall watchdog had ("fail-open") brought to the X28.

**Blocked by:** 02 — Dependency install + x28-health gate.

**Status:** resolved (dns-fix.sh probes the tunnel each run — boot, net
hotplug, operator switch, and every watchdog cycle — and configures DNS
upstream + a top RETURN bypass in the X28_SPLIT iptables chain to match
tunnel health; live-proven during the 2026-08-21 VPS outage: with the VPS
dead, Google/Gmail/international sites load direct; the watchdog flips the
path back automatically on the first healthy probe)

- [x] With the VPS down, LAN clients can load international sites direct
      (Google 200, Gmail 301 verified through the X28 path during the
      outage).
- [x] DNS answers (ISP fallback mode) while the VPS is down.
- [x] On VPS recovery the tunnel path self-restores within one watchdog
      cycle (~2 min): bypass rule removed, tunnel DNS upstream re-attached,
      split routing resumed.
- [x] Both directions are idempotent and serialized (lock), so boot-time
      rc.local / hotplug / watchdog concurrent invocations cannot mangle
      the config.
