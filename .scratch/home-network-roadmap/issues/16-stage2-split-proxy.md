# 16 — Stage-2: X28 as primary proxy edge

**What to build:** The X28 becomes the primary proxy edge: domestic traffic goes direct, international traffic goes through the VPS (split-proxying), with a one-command fallback on the AX3000T. The split routes on real quality data, so the quality layer must exist first.

**Blocked by:** 15 — Enable X28 guest/backup network tproxy; 04 — Quality-aware node rotation in the failover chain

**Status:** in-progress (stage2 scripts verified on X28; opt-in toggle pending user decision)

- [ ] Split verified per destination (domestic direct / international proxied).
- [ ] One-command fallback to the AX3000T stack works.
- [ ] Routing decisions use the quality data from 04.
