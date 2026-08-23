# 01 — Auto-reattribute ledger after device assignment

**What to build:** When a device is assigned to a person (via dashboard or bot), ALL historical owners-d data for that MAC should be immediately re-attributed to the new person, and the ledger card should refresh within seconds. No separate `/owner reattribute` command needed — it happens automatically.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [ ] x28-owners.sh assign and unassign call the reattribute logic automatically after successful assignment
- [ ] Dashboard assign action triggers ledger refresh after re-attribution
- [ ] Bot assign action triggers ledger refresh after re-attribution
- [ ] Re-attribution is idempotent (running twice changes nothing)
- [ ] Fixture test: assign device → owners-d files update → ledger reflects new attribution
