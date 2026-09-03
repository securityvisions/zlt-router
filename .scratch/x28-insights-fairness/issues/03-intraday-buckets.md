# 03 — Intraday hourly usage buckets

**What to build:** Today usage is collected continuously but stored only as daily totals, so nothing intraday can ever be charted. Extend the collector to also accumulate small hourly buckets (per resolved person/device), giving the household an honest hour-by-hour record. Buckets are tiny, rotated on a short bounded window, and checked against free space on the data partition before writing — the partition has well under a gigabyte free and must never fill. Data starts accruing immediately even though the chart that consumes it comes later.

**Blocked by:** 01 — Restore point; 02 — MAC alias continuity (buckets keyed by resolved owner).

**Status:** ready-for-agent

- [ ] Hourly buckets accrue per person with resolved-owner attribution
- [ ] Bounded retention with automatic rotation; worst-case footprint calculated and asserted in tests (KB-scale/day)
- [ ] Write path refuses when free space falls below a configured floor; collection degrades loudly, never fills the disk
- [ ] Collector failure cannot corrupt or stall the existing daily accounting (additive path only)
- [ ] Deploys via targeted pushes only; proxy engine untouched
