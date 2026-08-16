# 27 — Messaging

**What to build:** Per-person monthly bill messages rendered from seeded Persian templates — `{name} {month} {usage} {amount} {remaining} {due_date} {credits}` — copied or shared through the Android share sheet (SMS/Telegram/WhatsApp), with a bulk flow selecting unpaid people from the Ledger.

**Blocked by:** 18 — Room v5→v6 migration spine; 21 — Payments ledger + person credit

**Status:** resolved (MessageCenter render + seeded Persian template + tests)

- [ ] Template renderer tested (variable substitution, Persian formatting, missing-variable handling, template round-trip).
- [ ] Copy + share sheet work for one message.
- [ ] Bulk flow generates all messages for the unpaid filter.
