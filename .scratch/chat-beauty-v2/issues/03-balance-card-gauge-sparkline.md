# 03 — Balance Card: gauge + trend sparkline

**What to build:** The Balance Card becomes the visual centerpiece. From the local balance cache and the daily balance history, the card shows: a **quota gauge** (`▰▰▰▰▱▱▱▱ 59% · 89 GB left`) for the main plan, the main-plan detail line, a **trend sparkline** of the last ~14 daily snapshots from the balance log (dropping axis labels; the trend's recency is implied), the drain estimate, and the existing cached-as-of freshness footer. No live ISP call in the Panel path — still served from the cache.

**Blocked by:** 01 — Card v2 rendering core

**Status:** resolved

## Answer

`cmd_balance` rebuilt: parses the main-plan line from the balance cache (quota, remain, percent, expiry), renders a quota gauge via `bar`, a 14-point trend sparkline from the nightly balance logs via `spark`, the drain estimate, then the italic "cached as of HH:MM" footer **outside** the `<pre>` block (it previously sat inside the code block where HTML tags don't render). Falls back to the raw report if fields can't be parsed, and to a live ISP call if no cache exists. Verified on the router with the real cache: gauge/plan/trend/drain all parse and render, footer shows the freshness time. Deployed and running.

- [x] `/balance` shows the quota gauge, main-plan detail, and the history sparkline in one Card
- [x] The sparkline renders the daily series legibly (recent snapshots rightmost) and handles a one-point or empty history gracefully
- [x] The cached-as-of footer is retained; the live-ISP fallback still works when no cache exists
- [x] No HTML escaping errors; gauge/sparkline blocks render correctly in Telegram's `<pre>` block

- [ ] `/balance` shows the quota gauge, main-plan detail, and the history sparkline in one Card
- [ ] The sparkline renders the daily series legibly (recent snapshots rightmost) and handles a one-point or empty history gracefully
- [ ] The cached-as-of footer is retained; the live-ISP fallback still works when no cache exists
- [ ] No HTML escaping errors; gauge/sparkline blocks render correctly in Telegram's `<pre>` block

## Comments

History source: daily `GB` snapshots in the balance log (`date|total` lines). The gauge reflects remaining-vs-quota of the main plan; the sparkline reflects total remaining across all plans over time.