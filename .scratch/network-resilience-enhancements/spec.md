# Spec: Network Resilience, Privacy & Balance Monitoring Enhancements

Status: ready-for-agent

## Problem Statement

The router already ran a Telegram alerting/billing system (see `telegram-alerting-billing`), but several gaps remained:

- **Same-day data depletion was invisible.** The ISP's balance counters lag (verified: a 50 MB download didn't move them for 45 s+, and the number only reconciled hours later), so a heavy download evening could exhaust the package and the bot would only report it the next morning. The user had no answer to "what if I drain it in one day?"
- **Every balance check re-logged-in to the ISP** (3 round-trips, ~5 s, three failure points), and the report was a bare list — no percentage, no days-until-expiry, no usage-rate projection.
- **The balance feature treated packages naively**: it couldn't pick a main package, keyed its low alert on the *nearest* expiry (misleading once a dead secondary package existed), and would misread a newly-purchased package as "negative usage" in any rate calculation.
- **The router clock was UTC**, so all scheduled reports fired at Iran-unfriendly hours (the "09:00" Friday reminder fired at 12:30 Iran; the "21:00" daily usage report fired at 01:00 Iran).
- **No DNS-level ad/tracker blocking** existed, so every device on the network loaded web ads and trackers.
- **SQM was half-configured** (upload shaped at 13 Mbps, download unset at 0), so downlink bufferbloat wasn't managed.
- **The weekly Friday 40% discount** — the user's actual buying lever — wasn't prompted; it had to be remembered.

## Solution

A second wave of enhancements, all on the router at zero hardware cost:

1. **Iran timezone fix** — the router now runs on Asia/Tehran (IRST, no DST), verified at the crond level, so every scheduled job fires at Iran-local times.
2. **DNS ad-blocking** — a lean set of blocklists (≈164k domains) fed into dnsmasq; verified blocked domains return NXDOMAIN while normal sites resolve; memory-bounded to respect the router's RAM.
3. **Completed SQM** — CAKE shaping on both directions (download 35 Mbps, upload 10 Mbps) with rates measured from the live WAN, relocating the queue to the router where CAKE can manage it.
4. **Friday-discount reminder** — a weekly 09:00 (Iran) bot message on Fridays, toggleable from the bot, that includes the current package balance.
5. **Rewritten balance module** —
   - **Token caching**: one ISP login, reused for ~28 days; re-login only on auth failure; ~0.4 s checks instead of ~5 s.
   - **Multi-package aware**: a main package headline (most remaining), every plan listed, exhausted plans compressed, totals summed across plans; alerts keyed on total remaining + *latest* expiry.
   - **Balance history**: a daily snapshot log enabling an ISP-observed **drain rate** and a "days left" projection that ignores package-add days.
   - **Tiered alerts**: 🔶 notice / 🟠 warn / 🔴 urgent / 📛 exhausted, per-tier state, alerting only on escalation, with a Friday-discount nudge on the urgent tiers.
   - **Realtime depletion monitor**: every 15 minutes it estimates `remaining ≈ last confirmed ISP reading − realtime usage since then` (from nlbwmon), and alerts within minutes when a heavy download crosses a threshold — not the next morning.

## User Stories

1. As a user, I want the router's clock and all scheduled reports to be in my local (Iran) time, so a "09:00 Friday" reminder actually arrives at 09:00 Iran.
2. As a user, I want the Friday-discount reminder to fire on real Fridays, so I never miss the 40% saving on my package renewal.
3. As a user, I want to be able to silence the Friday reminder from the bot (`/fridayremind off`) and re-enable it later, so it never nags when I don't want it.
4. As a user, I want web ads and trackers blocked at the DNS level for every device on the network, so browsing is faster, lighter, and more private.
5. As a user, I want normal websites to keep resolving correctly while ad domains are blocked, so the blocking never breaks the internet.
6. As a user, I want the ad-blocking to be lean enough not to starve the router of memory, so the proxy and bot keep working.
7. As a user, I want the network to stay responsive under load (downloads no longer spiking everyone's latency), so SQM actually shapes both directions.
8. As a user, I want SQM rates to reflect the real WAN speed, so shaping doesn't throttle my line.
9. As a user, I want a single daily balance message that shows total data left, the main package's remaining and percentage, and the expiry date.
10. As a user, I want the balance report to show how fast the package is draining and how many days that implies, so I can plan renewals.
11. As a user, I want to know when my package will run out *based on my usage rate*, not just today's raw number.
12. As a user, I want the balance feature to handle multiple packages — including buying a new 150 GB plan while an old one still has data — summing them and picking a sensible main package.
13. As a user, I want exhausted secondary packages collapsed into a single muted line instead of cluttering the report.
14. As a user, I want to be warned early (notice), then more strongly (warning), then urgently as data runs low, so I can act progressively instead of being ambushed.
15. As a user, I want an alert the moment the data is estimated to be exhausted, so I know to renew immediately.
16. As a user, I want an urgent alert to remind me it's Friday and the discount is available, so I renew at the best price.
17. As a user, I want balance checks to be fast because the login is cached, so the bot's balance button responds quickly.
18. As a user, I want the system to recover automatically when the ISP session expires, without me doing anything.
19. As a user, I want a heavy one-day download to be caught the same day — not the next morning — so I can stop it or renew in time.
20. As a user, I want to be told when the consumption *rate* is dangerously high ("burning ~8 GB/h"), so I understand the urgency even if the exact remaining is fuzzy.
21. As a user, I want the monitor to re-sync to the ISP's real numbers periodically, so the estimate never drifts permanently.
22. As a user, I want the monitor to not spam — alerts only when things get worse, and rate alerts throttled.
23. As a user, I want the drain-rate calculation to ignore days when a new package was added, so the projection isn't corrupted by a purchase.
24. As a user, I want the system to keep working within the router's storage and memory budget, so the proxy, bot, and adblock are unaffected.
25. As a user, I want a clear error message (and a retry) if the ISP check fails, so I know it's credentials/network and not silent failure.
26. As a user, I want the Friday reminder to include my current balance, so I can decide at a glance whether to renew.
27. As a user, I want the balance history to accumulate over time, so the drain-rate estimate becomes accurate after a few days.
28. As a user, I want all thresholds (warn/urgent GB, days, rate) configurable, so I can tune them to my plan.
29. As a user, I want the whole thing reversible — remove the monitor cron, restore the old balance script — without touching anything else.
30. As a user, I want the scheduled jobs to survive reboot, so monitoring and reminders continue after a power cycle.

## Implementation Decisions

### Modules modified

- **Balance checker (rewritten)** — the core of this wave. Responsibilities now:
  - *Auth caching*: an access token (and ~28-day expiry) is cached; every check reuses it; an auth-failed response (`statusCode 6`) clears the cache, re-logs in, and retries once. All network calls carry explicit timeouts.
  - *Multi-package parsing*: every data package from the ISP response is read (quota, remaining, expiry), sorted by remaining; the largest becomes the "main" package; the sum of all remaining is the account total; packages with ~0 remaining are counted as expired and compressed in the report.
  - *History + drain rate*: a daily snapshot of the total (`date|total`) is appended to a per-month text log; the drain rate is computed from consecutive positive deltas, so any day where the total *rose* (a purchase) is skipped; projection = total ÷ rate.
  - *Tiered alerting*: a single tier decision function maps (total, percent, min expiry days, projected days) to none/notice/warn/urgent/exhausted; a per-tier state file records the current tier; an alert is sent only when severity escalates, and the state resets downward silently when data improves (e.g., after a purchase).
  - *Realtime depletion monitor*: an "anchor" file records `{epoch, total, main quota, nlbw total, min expiry days}` each time a confirmed ISP reading succeeds. Between readings, the monitor estimates remaining as `anchor total − (current nlbw total − anchor nlbw total)`, re-decides the tier from that estimate, and separately alerts when the instantaneous consumption rate exceeds a threshold (≥5 GB/h) while estimated remaining is < 30 GB, throttled to once per 4 hours. The anchor refreshes on a configurable interval (default 60 min) or when a tier is crossed.
  - *Report*: a single compact message — total across plans, main package quota/remaining/percentage, days to expiry, drain rate and projected days, a compressed "expired plans" line, and an honesty note that the ISP updates slowly.

- **Friday reminder (new)** — a small scheduler-friendly script: honors an on/off toggle, re-checks that today is Friday, sends the reminder, and best-effort appends the balance headline. A new bot command toggles the flag.

- **Scheduled jobs** — cron entries added for the monitor (every 15 min) and the Friday reminder (09:00 every Friday, Iran).

### Configuration

- System timezone set to Asia/Tehran (POSIX `IRST-3:30`), `/etc/localtime` regenerated by the system init, verified that crond schedules on Iran time.
- Balance thresholds and monitor refresh interval live in the router config: warn GB, urgent GB, warn/urgent days, rate alert GB/h, refresh minutes. Defaults chosen for a 150 GB plan (warn 10 GB, urgent 3 GB, warn 7 d, urgent 3 d, rate 5 GB/h, refresh 60 min).

### Ad-blocking

- DNS-level via dnsmasq; three feeds (general ads + two small lists) yielding ~164k domains — deliberately lean so dnsmasq stays ~15 MB of RAM instead of ~31 MB with the larger default set. The blocklist is built into a dnsmasq include directory in RAM and rebuilt on boot; the service is enabled at boot. Verified blocked domains answer NXDOMAIN and normal domains resolve.

### SQM

- CAKE on the WAN for both directions; download and upload rates set from live speed measurements (≈35 Mbps down, ≈10 Mbps up). Because the router sits behind the ISP's device (double NAT), shaping relocates the queue to this router where CAKE can manage it; this is a mitigation, not a full fix for upstream bufferbloat.

### Architectural constraints honored

- No new heavy runtime; everything is short-lived shell + an existing JSON tool.
- All volatile state in RAM; the only persistent additions are tiny text logs (balance history).
- The realtime estimate is explicitly approximate: ISP counters lag, so a safety margin is built into the warn threshold, and the rate alert covers the fuzzy-remaining case.

## Testing Decisions

### What makes a good test

Test external, observable behavior — the Telegram message that lands in the chat, the DNS answer the network actually gets, the shaping that `tc` reports, the time crond fires — not script internals.

### Modules to test

- **Timezone**: `date` shows IRST; a live one-shot cron job logs the exact minute it fired and matches Iran time; nearest Friday computed from the Iran calendar.
- **Ad-blocking**: a known ad domain (`doubleclick.net`) resolves NXDOMAIN; a normal domain resolves; dnsmasq RSS stays bounded (~15 MB); the service is enabled at boot.
- **SQM**: `tc qdisc show` on the WAN and its ingress device both show CAKE with the configured bandwidths.
- **Balance auth caching**: first check logs in (creates the token cache); a second check is fast (<1 s) and doesn't re-login; forcing an expired/invalid token triggers a clean re-login and recovery.
- **Balance report**: totals match the ISP response; the main package is the largest; a dead secondary package is compressed; days-to-expiry is correct.
- **Drain rate/projection**: with a two-day history the rate and projected days match hand-computed values; a day where the total rises (purchase) is excluded from the rate.
- **Tiered alerts**: each tier transition (none→notice→warn→urgent→exhausted) fires exactly one message; a recovery (e.g., a new purchase raising the total) resets downward silently.
- **Monitor**: with a fresh anchor, estimated remaining = anchor − realtime nlbw delta; crossing warn/urgent on the estimate fires; the rate alert (>5 GB/h, <30 GB) fires once per throttle window; re-anchor occurs after the refresh interval.
- **Friday reminder**: `--test` sends immediately; toggle off silences it; on a real Friday the cron path fires once.

### Prior art

The build was verified live on the router: the token cache cut a check from ~5 s to 0.37 s; the report was checked against the live 150 GB plan (146.5 GB left, 97%); a simulated 2-day history produced "~3.5 GB/day → ~41d left"; adblock verified with NXDOMAIN; SQM verified via `tc`; crond verified firing at Iran 01:58; the Friday reminder delivered message with the balance headline.

## Out of Scope

1. **Package purchase/payment automation** — read-only balance monitoring only.
2. **Second WAN / load-balancing** — the proposed 5G CPE (ZLT X28) was evaluated and rejected: the fixed line rarely drops, the device isn't cheap, and load-balancing over a metered SIM with PassWall is actively counterproductive.
3. **Per-device QoS (eqos)** and guest bandwidth caps.
4. **Ad-block category filtering** (adult/social) beyond the current blocklist set.
5. **Historical dashboards/UI** for balance — text reports only.
6. **Multi-account support** — single Samantel account.
7. **Fixing upstream bufferbloat** at the ISP device (out of this router's control).

## Further Notes

- The ISP's balance counters update slowly (batch-style), so the monitor's estimate can be optimistic by roughly `lag × rate`; the 10 GB warn margin and the rate alert exist precisely to cover that.
- nlbwmon measures LAN usage through the router; small discrepancies vs the ISP counter have been observed (attributed to counter lag), so the estimate re-anchors to the ISP on every confirmed reading.
- The drain-rate projection becomes accurate only after a few days of nightly snapshots; until then the report says data is still being collected.
- The earlier `telegram-alerting-billing` spec covers the base alerting/billing system; this spec covers the second wave layered on top.
- Rollback for this wave: restore the previous balance script, remove the monitor and Friday cron entries, uninstall adblock, revert the timezone, restore SQM rates — each is independent and reversible.
