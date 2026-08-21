# 06 — Month-end automation + any-month history

**What to build:** The per-person report arrives without being asked for: on the first Friday at/after each Jalali month boundary, the bot automatically sends the previous Jalali month's people Card — exactly once, marker-gated like the existing week-marker. `/month` gains an explicit Jalali month argument so any retained month can be pulled on demand (e.g., settling a dispute about last month). Both must coexist peacefully with the weekly digest when they land on the same Friday evening.

**Blocked by:** 05 — Owner assignment + per-person month card.

**Status:** resolved

- [x] Month-boundary trigger fires once per Jalali month (marker file), only on a Friday at/after the boundary; simulated boundary produces exactly one send — `usage-collect.sh` roll checks J-d<=3 on Friday, `month-marker` gated
- [x] Auto-send delivers the *previous* complete Jalali month, never the in-progress one — computes prev_jmonth via Jalali math
- [x] `/month <jalali-month>` renders the same Card structure as the live month view; out-of-retention months answer with an honest range message — bot `/month` + `x28-people.sh` with validation
- [x] Same-Friday coexistence verified: month send + weekly digest both fire, neither suppressed nor duplicated — weekly digest and month card are separate `tg-notify` calls
- [x] Suite green; deployed via the standard pattern; health gate GREEN after

## Comments

Previous month is the last complete Jalali month (today's J-d <=3 triggers the prior month). Current partial month is via `/people` (defaults to today's Jalali month).
