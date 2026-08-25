# 04 — Apply Valve routes into the tunnel (unblock PC Steam voice now)

**What to build:** The engine's TUN device is up and its rules pin Valve traffic to the hysteria2 node, but the routes that send Valve IPs into that TUN were never applied — so PC Steam voice still leaves through the carrier and hangs at "connecting". Run the canonical enable script against the live router, confirm the kernel now resolves Valve addresses via the TUN device, and hand the user a working path to retry voice immediately. Reversible with one disable script; no engine restart involved.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [x] Enable script executed against the live router without error
- [x] Kernel route lookup for a Valve voice-range address resolves via the TUN device
- [x] Rollback path verified available (disable script removes exactly these routes)

## Answer

2026-08-25: canonical enable script deployed and executed live — all five Valve CIDRs routed (`ip route show` count = 5); kernel lookup for 162.254.197.84 now resolves `dev utun src 198.18.0.1` (was `dev ccmni1`). Disable script present at the same path for one-command rollback. udp-diag: egress PASS, Steam range reachable, pinned node hy2 @362 ms.
