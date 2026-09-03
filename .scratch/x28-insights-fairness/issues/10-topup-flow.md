# 10 — Top-up deep-link flow

**What to build:** When a nudge fires (or the family asks), completing the purchase is still manual — but everything around it is automated: the bot/dashboard produces the right deep-link/QR for the vendor's own top-up page, reminds at sensible intervals until the standing shows a fresh pack, and logs the completed top-up into the Ledger as an event so spend history lives next to usage history. Payment rails stay entirely external and human-executed.

**Blocked by:** 08 — Vendor standing pull; 09 — Predictive top-up nudge.

**Status:** ready-for-agent

- [ ] One tap/command produces the correct top-up link/QR for the current SIM
- [ ] Reminder loop arms on nudge, disarms automatically when vendor standing shows a fresh pack
- [ ] Completed top-ups logged as Ledger events (visible in history views)
- [ ] No automated payment execution anywhere — link generation and reminders only (asserted)
- [ ] Deploys via targeted pushes only; proxy engine untouched
