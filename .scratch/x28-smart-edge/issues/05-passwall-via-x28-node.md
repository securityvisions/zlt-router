# 05 — PassWall via-X28 node + failover chain

**What to build:** The AX3000T's PassWall gains a node pointing at the X28 SOCKS, switchable via the existing node mechanism. The full failover chain (REALITY → Hysteria2 → via-X28 → direct) is the follow-up: extend the fail-open/autorecover watchdogs to walk the chain instead of jumping straight to direct.

**Blocked by:** Ticket 04

**Status:** in-progress (node live; failover chain open)

- [ ] Switching PassWall tcp_node to via_x28 keeps internet working (egress = VPS); a dead VPS node falls back through the chain before going direct.
