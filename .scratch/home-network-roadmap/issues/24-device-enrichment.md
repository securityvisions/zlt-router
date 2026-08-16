# 24 — Device enrichment + ownership suggestions

**What to build:** Devices gain IP, last-seen, type, tags, and an analytics/billing exclusion flag; the poll updates presence from the clients feed. Ownership suggestions carry a reason and confidence — and are never auto-assigned.

**Blocked by:** 18 — Room v5→v6 migration spine

**Status:** resolved (Enrichment + tests; poll updates ip/lastSeen)

- [ ] Poll updates device IP and last-seen.
- [ ] Excluded devices drop out of ranking, insights, and history.
- [ ] Ownership suggestions show reason + confidence and are never auto-assigned.
