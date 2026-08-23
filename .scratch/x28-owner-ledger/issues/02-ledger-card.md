# 02 — Ledger card: Persian-first HTML with bars & breakdowns

**What to build:** The People/Month card becomes the household Ledger in the bot's HTML system: Persian-first title with Jalali month, one row per person sorted by GB — share bar (▰▱), GB, Toman, share % — an always-visible unassigned row with a nudge when non-zero, totals line, and an expandable per-device breakdown per person fed by the new granular rollups. `/people <name>` filters to that person's breakdown. Plain-text mode preserved for alerts/digest.

**Blocked by:** 01 — reads the device-granularity rollups.

**Status:** ready-for-agent

- [ ] Golden-card tests from fixture months: bars, shares, Toman rounding, Persian labels, esc()d names, unassigned row + hint only when non-zero
- [ ] Per-person filter (`/people <name>`) renders that person's device breakdown
- [ ] Aggregation math verified against fixture rollups incl. mid-month reassignment
- [ ] Bot /people · /month · Panel tap all render the HTML card; digest keeps plain mode
