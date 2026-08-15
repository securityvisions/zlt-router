# 12 — X28 as primary proxy edge with split routing (Stage 2)

**What to build:** The X28 runs the full domestic/international split + transparent proxy as the primary proxy path; the AX3000T's PassWall switches to direct (kept as a one-command fallback), freeing its RAM. Only after Stage 1 proves stable.

**Blocked by:** Tickets 04, 05, 11

**Status:** open

- [ ] International traffic egresses via the VPS and domestic traffic goes direct, both verified per destination; the AX3000T fallback works with one command.
