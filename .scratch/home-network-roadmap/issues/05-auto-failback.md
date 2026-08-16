# 05 — Auto-failback with hysteresis

**What to build:** After the chain rotated away from the preferred node, the network returns to it automatically once it is healthy for 2 consecutive checks — hysteresis so two near-equal nodes don't flap back and forth. Self-healing without oscillation.

**Blocked by:** 04 — Quality-aware node rotation in the failover chain

**Status:** resolved (auto-failback with 2-check hysteresis; tests)

- [ ] Failback decision seam with a hysteresis counter; fixture-tested (returns after 2 healthy checks, no flap at 1).
- [ ] Bot notification on return to the preferred node.
- [ ] Live: a recovering preferred node is re-adopted.
