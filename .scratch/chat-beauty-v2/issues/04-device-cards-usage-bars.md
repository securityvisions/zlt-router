# 04 — Device cards: per-device usage bars

**What to build:** The device-facing Cards get a visual hierarchy. Usage, Clients, and Known-devices show each device as an aligned row with a **usage bar scaled to the top consumer** (largest user gets a full bar; others are proportional) and the byte total right-aligned in a monospace column. Unknown/unnamed devices are tightened without losing their MAC. Empty state ("no devices") remains a clean single-line Card, not a blank reply.

**Blocked by:** 01 — Card v2 rendering core

**Status:** resolved

## Answer

Added `dev_usage_rows` (awk builder producing `name  ▰▰▰▱▱▱▱  GB` rows scaled to the top consumer, names truncated to 16 chars) and migrated the three device views to it: `/usage` (today's per-user data), `/clients` (connected devices, today's bytes looked up per name, 0 if unknown), and `/names` (lifetime totals). Empty rows → clean "no devices" Card. Verified on the router with a four-device sample: bars scale correctly, zero-usage devices render an empty bar, columns align. Deployed and running.

- [x] `/usage` lists devices with per-device bars scaled to the top user and aligned GB totals
- [x] `/clients` and `/names` apply the same bar + padded-column treatment
- [x] A large device list still renders within Telegram's message limits (bars degrade gracefully, not truncated mid-card)
- [x] Empty state returns a tidy "no devices" Card
- [x] No HTML escaping errors in the rendered Cards

- [ ] `/usage` lists devices with per-device bars scaled to the top user and aligned GB totals
- [ ] `/clients` and `/names` apply the same bar + padded-column treatment
- [ ] A large device list still renders within Telegram's message limits (bars degrade gracefully, not truncated mid-card)
- [ ] Empty state returns a tidy "no devices" Card
- [ ] No HTML escaping errors in the rendered Cards

## Comments

Bar semantics: `bar` sized from a 0–max scale where max = top consumer, so the heaviest user's bar is full and the rest are relative — instant visual ranking.