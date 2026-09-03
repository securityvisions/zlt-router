# 02 — MAC alias continuity: device swaps keep history

**What to build:** When someone's phone re-registers on the network it gets a new MAC today, and the Ledger treats it as a brand-new person-device — splitting history. Add alias support to the owner-attribution seam: an old-MAC→current-MAC mapping consulted wherever attribution resolves, so a reassigned phone continues its person's series. Assignment surfaces (dashboard chips, bot panel) gain a "reassign, keeping history" flow, and the existing backfill tool understands aliases so past day-files can be re-attributed on demand without rewriting raw data.

**Blocked by:** 01 — Restore point (first ticket permitted to touch attribution).

**Status:** ready-for-agent

- [ ] Alias map lives beside the owners file; attribution resolves through it everywhere (live attribution, day-walk aggregation, backfill)
- [ ] Dashboard + bot assignment flows offer "keep history" reassignment; plain re-assignment still possible
- [ ] Backfill run on aliases re-attributes historical rows correctly (fixture-tested, idempotent)
- [ ] Raw day-files are never mutated by aliasing — resolution happens at read/aggregation time
- [ ] Deploys via targeted pushes only; proxy engine untouched
