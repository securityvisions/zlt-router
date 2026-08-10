# 05 — Dashboard v2 sweep (Panel entry + remaining commands)

**What to build:** The Panel's entry message becomes a true dashboard Card, and every remaining reply joins the v2 anatomy. The dashboard composes the balance gauge + sparkline (ticket 03), the device/usage summary (ticket 04), proxy state, disk gauge, and load/temp in one aligned Card above the button grid. The remaining commands — Disk, Proxy, Cost, Bill, Test, Help — are migrated to the same anatomy (title, section rule, aligned columns, tier badge where a state or tier exists), so no Panel or slash reply reads differently. A final consistency pass checks every visible reply, including error/help prompts.

**Blocked by:** 03 — Balance Card: gauge + trend sparkline, 04 — Device cards: per-device usage bars

**Status:** ready-for-agent

- [ ] `/panel` shows the dashboard Card (balance gauge+spark, device summary, proxy, disk, load/temp) above the grid
- [ ] Disk, Proxy, Cost, Bill, Test, and Help replies use the v2 anatomy
- [ ] A sweep of every slash command and panel button returns a Card with consistent anatomy and no HTML errors
- [ ] The dashboard composes the ticket-03 and ticket-04 pieces without duplicating their logic

## Comments

The dashboard reuses the balance and device Card builders from 03/04 rather than re-deriving the data; the Panel entry becomes the single richest Card in the bot.