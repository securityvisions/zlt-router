# 05 — Deploy + docs + live smoke

**What to build:** Batch wrap-up: rollback snapshot before first deploy of this batch; deploy everything with the standard push pattern + health gates; CONTEXT.md glossary gains Ledger page and Device assignment; AS_BUILT addendum covers the new stores (owners-d/, ledger/) and panel callbacks; OPERATIONS self-heal/troubleshooting mentions the owner flow; live smoke exercises backfilled history, an assignment, and a frozen-page view.

**Blocked by:** 01, 02, 03, 04.

**Status:** ready-for-agent

- [ ] Snapshot taken before first deploy of the batch (manifest + restore notes)
- [ ] Docs updated in house style; suite + web typecheck green
- [ ] Live smoke: backfilled ledger card shows real history; one assignment via buttons; frozen-page view renders; health gate GREEN after each deploy step
