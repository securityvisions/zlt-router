# 06 — End-to-end proof: PC Steam voice connects through the tunnel

**What to build:** With routes applied and boot persistence hardened, prove the whole chain with real traffic: the diagnostic shows UDP egress to a foreign endpoint riding the pinned node, and the human test — joining the Steam voice channel from the PC — connects and holds without the connect/reconnect loop. Latency expectation set honestly (~350–420 ms via the node; workable for push-to-talk style chat, not competitive). If the human test still fails, capture which stage breaks (route hit? engine counters? node relay?) before calling anything done.

**Blocked by:** 04 — Apply Valve routes; 05 — Boot-race self-heal.

**Status:** claimed

- [ ] Diagnostic: UDP egress PASS and Steam-range check rides the pinned node
- [ ] Engine connection telemetry shows Valve flows entering via the TUN inbound
- [ ] Human test: voice channel connects and holds ≥5 minutes without reconnect loop
- [ ] Failure path documented if it breaks (which stage, what evidence) rather than declared done
