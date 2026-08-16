# Two-device home network: the X28 and AX3000T are the entire appliance

The home network is a fixed **two-device appliance**: the ZLT X28 (`192.168.70.1`)
is the **WAN appliance** (cellular modem + crypto engine + backup proxy engine),
and the Xiaomi AX3000T (`192.168.1.1`) is the **smart edge** (routing, PassWall,
control plane, bot, Router API). All growth is *extraction from these two boxes*;
the VPS (s-ui) tier is the only sanctioned upgrade lever. No new routers, SIMs,
or hardware are added.

Every feature must answer two questions: **which box runs it, and does it fit?**
(Both boxes are small: the X28 has 643 MB RAM, the AX3000T 239 MB — feature
design budgets resources, it does not assume headroom.)

**Status:** accepted

**Why:** the X28 is the only WAN path on site (single SIM slot, the only cellular
hardware) and is unlocked to act as a smart edge; the AX3000T already hosts the
entire control plane. A second WAN path was considered and rejected once already
(`.scratch/network-resilience-enhancements`: load-balancing rejected) before the
smart-edge work revived the X28 for the edge role — a future reader will wonder
why, and this records it.

**Considered:**

- **Load-balanced second WAN path** (a second modem/SIM) — rejected: cost and
  complexity, and in Iran a second consumer link is no more reliable than the
  first, so it buys little for a lot.
- **X28 as a pure modem** (AX3000T does everything) — rejected by the smart-edge
  phase: the X28's crypto engine and backup proxy offload the AX3000T and
  provide a degraded-but-alive fallback path.

**Consequences:**

- **Single point of failure:** the X28 is the sole WAN path. Reliability work
  (Phase A of the roadmap) mitigates — it never removes this.
- **Capacity is capped** by the two consumer boxes; anything resource-heavy must
  fit inside them or be rejected.
- **The VPS is the only scalar:** bandwidth/instance tier upgrades are the
  sanctioned growth lever.
