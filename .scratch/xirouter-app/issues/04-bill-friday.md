# 04 — Bill & Friday setting

**What to build:** The router Bill endpoint (monthly, per device) plus a Friday endpoint that writes the router's LAST_FRIDAY flag; the app's Bill screen and the persistent Friday toggle in Settings. Flipping Friday in the app makes the bot's scheduled reports use the discounted rate.

**Blocked by:** 01, 02

**Status:** ready-for-agent

- [ ] /bill returns the monthly per-device Toman table
- [ ] /friday writes LAST_FRIDAY and the bot's next report uses it
- [ ] App Bill screen + Settings Friday toggle work
