# 13 — Ad economics: blocked-ads telemetry

**What to build:** Make the adblocker's value visible and slightly fun: how many ad requests/MB were blocked for each person this month, shown as a small card ("the blocker saved you ~140 MB of ads"). Measurement approach is genuinely unknown today — start with a cheap spike comparing DNS-level block-hit counting vs matching blocklist IPs in traffic accounting, pick one with evidence, then build the counter and card on the winner.

**Blocked by:** 02 — MAC alias continuity (per-person attribution); includes its own spike gate before the build half.

**Status:** ready-for-agent

- [ ] Spike documented: both measurement approaches prototyped cheaply, one chosen with recorded evidence (accuracy vs cost on-device)
- [ ] Blocked-ad volume accrued per resolved person from the chosen source
- [ ] Dashboard card renders per-person monthly blocked totals in plain language
- [ ] Counter failure never touches the blocker's actual blocking behavior (purely observational path)
- [ ] Deploys via targeted pushes only; proxy engine untouched
