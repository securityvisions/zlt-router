# 04 — Quality-aware node rotation in the failover chain

**What to build:** The failover chain picks nodes by *measured quality*, not just probe-aliveness. On a healthy probe it still rotates when the active node is degraded and a fallback is materially faster — the "6.5 Mbps while the preferred node is slow" case that today does nothing. Fail-open stays the terminal rung: the chain can never take the network down.

**Blocked by:** 03 — Link-quality measurement module

**Status:** resolved (quality-aware rotation; fail-open stays terminal; tests)

- [ ] The chain's decision seam takes per-node quality; the test matrix covers healthy / degraded / slow-active-vs-fast-fallback.
- [ ] Rotation happens on degraded-but-alive; no rotation when the fallback isn't materially better.
- [ ] Fail-open remains the last rung.
- [ ] Deployed live; the bot/Panel shows which node is active.
