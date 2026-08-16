# 08 — App link card

**What to build:** The Xirouter app renders the X28 link card (operator, tech, RSRP, band) consuming `GET /link` per the API contract, so the family sees the WAN edge without the bot. Requires an Android build environment (none on the current dev box).

**Blocked by:** None — `GET /link` is already live.

**Status:** resolved (app link card on Home consuming GET /link)

- [ ] Link card renders operator / tech / RSRP / band from the API contract shape.
- [ ] Error and empty states match the contract (500 / "link unavailable").
- [ ] Persian-first with explicit LTR containers for MAC/IP fields.
