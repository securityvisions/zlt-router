# 06 — End-to-end proof: PC Steam voice connects through the tunnel

**What to build:** With routes applied and boot persistence hardened, prove the whole chain with real traffic: the diagnostic shows UDP egress to a foreign endpoint riding the pinned node, and the human test — joining the Steam voice channel from the PC — connects and holds without the connect/reconnect loop. Latency expectation set honestly (~350–420 ms via the node; workable for push-to-talk style chat, not competitive). If the human test still fails, capture which stage breaks (route hit? engine counters? node relay?) before calling anything done.

**Blocked by:** 04 — Apply Valve routes; 05 — Boot-race self-heal.

**Status:** claimed

- [ ] Diagnostic: UDP egress PASS and Steam-range check rides the pinned node
- [ ] Engine connection telemetry shows Valve flows entering via the TUN inbound
- [ ] Human test: voice channel connects and holds ≥5 minutes without reconnect loop
- [ ] Failure path documented if it breaks (which stage, what evidence) rather than declared done

## Comments

> 2026-08-26 ~01:30 — regression investigated, real root cause found (twice). First attempt failed not because routes were missing but because they were added to the WRONG table: the vendor firmware policy-routes all LAN-originated traffic (`from 192.168.70.0/24 lookup 17000`), so main-table utun routes were invisible to forwarded PC traffic — `ip route get <valve> from <pc> iif br0` resolved `dev ccmni1 table 17000`. Second gap: Valve's real allocation is 155.133.128.0/17 (observed relays at .224/.226/.230/.238/.246/.248/.252), not the /20 we shipped. Fix: enable/disable scripts now add/remove routes in BOTH main and vendor table 17000; CIDR widened in all three sources (drift-guard enforced); engine hot-reloaded (HTTP 204); stale carrier-pinned conntrack entries surgically purged. Post-fix conntrack shows fresh Valve flows with reply dst = LAN client (no WAN MASQ) — tunnel path confirmed at the packet level. Human voice test pending.
