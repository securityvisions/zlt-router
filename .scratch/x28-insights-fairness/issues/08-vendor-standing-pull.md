# 08 — Vendor standing pull

**What to build:** The dashboard hero shows our own accounting of remaining data today; this ticket adds what Samantel itself sees — official remaining quota, expiry date/timestamp of the current pack, and any zero-rated or bonus buckets the vendor API exposes — refreshed on a slow poll and surfaced in the hero plus the bot status reply. Read-only: only vendor query commands already proven by the budget feature; any command not previously exercised read-only is out of scope.

**Blocked by:** 01 — Restore point.

**Status:** ready-for-agent

- [ ] Official standing (remaining, expiry, bonus/zero-rated buckets if exposed) visible on dashboard hero + bot status
- [ ] Vendor session handling reuses the proven login/query path; no new write commands introduced anywhere
- [ ] Vendor API failure degrades to our own accounting view with a "stale" marker — never blanks the hero
- [ ] Poll cadence conservative (respects the modem's management plane); fixture tests cover parsing against recorded responses
- [ ] Deploys via targeted pushes only; proxy engine untouched
