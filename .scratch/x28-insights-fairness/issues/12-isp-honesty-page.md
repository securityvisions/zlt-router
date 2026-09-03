# 12 — ISP-honesty page

**What to build:** A page that shows the household what the ISP actually sees and why it sometimes differs from our own numbers: official standing vs local accounting side by side, pack expiry, zero-rated/excluded buckets explained in plain language, and the small-print traps of the current tier (what counts, what doesn't, when Friday pricing applies). The goal: when the family asks "why does the app say 12 GB but we counted 9?", this page answers without an argument.

**Blocked by:** 08 — Vendor standing pull.

**Status:** ready-for-agent

- [ ] Side-by-side view: vendor standing vs local accounting for the same window, with discrepancy explained where known
- [ ] Plain-language explainer section for zero-rating, expiry, and tier rules as currently understood
- [ ] Stale vendor data visibly marked, never silently mixed with fresh local data
- [ ] Content sourced from data (standing pull + billing config) so it updates itself — no hand-maintained prose that rots
- [ ] Deploys via targeted pushes only; proxy engine untouched
