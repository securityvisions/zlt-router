# 25 — Saved views + command-palette search

**What to build:** Saved views — "unpaid", "unknown devices", "offline" — appear as chip rows on the Ledger and Device workspace, and a command-palette overlay gives grouped global search across people, devices, MACs, IPs, packages, notes, months, and payments.

**Blocked by:** 18 — Room v5→v6 migration spine

**Status:** resolved (Search + saved_views DAO + tests)

- [ ] Saved views persist their filter as JSON and apply one tap from chips.
- [ ] Command-palette search covers the listed entity groups (grouped LIKE search, no FTS).
- [ ] Search and views are Persian-first/RTL-correct.
