# 01 — UDP-path diagnostic

**What to build:** A repeatable diagnostic script that answers two questions: (1) is direct UDP from the LAN to Steam's voice servers actually filtered, and (2) which proxy node has the lowest round-trip latency. It ranks the auto-group nodes via the engine's per-node delay probes, tests UDP egress to a foreign resolver, checks reachability to known Valve voice-range IPs, and prints a verdict plus the exact PC-side UDP test to run on the machine playing Steam. The verdict decides whether ticket 02 gets built, and its node ranking feeds ticket 03's choice.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [x] Diagnostic ranks auto-group nodes by measured latency (parallel per-node probes)
- [x] UDP egress check reports PASS/FAIL against a foreign resolver
- [x] Steam voice-range IP reachability check (ICMP + TCP) plus a printed PC-side UDP test command
- [x] A verdict function that turns egress + reachability + best-node latency into a clear recommendation
- [x] Fixture tests: node ranking from a stubbed controller; verdict from overridable check results
- [x] Run live on the X28; verdict recorded and reported
## Answer

Built as `udp-diag.sh` (nodes/egress/steam/verdict/all) with fixture tests. Live verdict 2026-08-24: direct LAN UDP to Valve ranges filtered/unreliable through the carrier; auto-group ranking produced hy2 as the UDP-native pick. Verdict triggered the design pivot recorded on 02.
