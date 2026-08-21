# x28-smart-reports — spec

Status: ready-for-agent

## Problem Statement

The household's only internet path is the X28, and the data that describes it is scattered across stores nobody reads: per-device daily accounting files, hourly telemetry rows, the Samantel balance cache, and the operator watchdog's probe log. From the user's side this means:

- The Samantel package runs out (or nearly runs out) without warning — there is no forecast and no tiered alert before the internet dies mid-month.
- There is no record of how often or how long the internet was actually down each month, so "MCI owed me 3h40m" can never be claimed with evidence.
- Every Friday produces only a bare usage/bill card — no signal quality, no outages, no balance outlook — so the week's story has to be assembled by hand.
- Monthly consumption cannot be attributed per person: several people share several devices, and the months everyone lives by are Jalali months, which no router-side code understands today.
- Handing WiFi to a guest means reading a password off a screen; there is no scannable share code.
- A real multi-WiFi setup (guest / unfiltered / direct) is wanted but must not risk the only working router: the X28's SSID config is vendor-owned, undocumented, and was already wedged once by a vendor firmware reload.

## Solution

Six additions to the X28 brain, all delivered through the Telegram bot as Cards, all read-only with respect to the network path:

1. **Data Budget Guardian** — forecast of month-end usage and package exhaustion with tiered alerts (defaults: warn <10 GB / <7 days / projected <14 days; urgent <3 GB / <3 days / projected <7 days; exhausted <0.05 GB), cooldown-gated so alerts don't spam, plus an on-demand `/budget` card.
2. **Outage SLA Ledger** — the watchdog's existing probe transitions now append down/up events to a new append-only ledger; durations are paired on read and totaled per Jalali month, surfaced via `/outages` ("MCI owed you XhYm").
3. **Weekly Digest Card** — the Friday ~20:00 send becomes one full card: GB + Toman for the week, top devices, outage minutes, balance + forecast, RSRP/operator/uptime; also triggerable manually via `/digest`.
4. **Per-person monthly report in the Jalali calendar** — devices are assigned to people through a bot `/owner` flow; a permanent per-owner daily rollup (written before day-file pruning) makes completed Jalali months computable forever; on the first Friday after each Jalali month-end the bot sends a per-person GB/Toman/device-count card in Persian, with `/month` for any recent month on demand.
5. **WiFi share (`/wifi`)** — an image QR of the main SSID credentials, generated on the router with a static `qrencode` and sent as a photo; graceful fallback message when creds aren't provisioned.
6. **Vendor guest-SSID research** — strictly read-only discovery of where the vendor keeps SSID config and whether a native guest-network toggle exists, recorded as findings; outcome decides whether a safe future guest SSID exists on the X28 or real second SSIDs wait for the recovered AX3000T.

Safety envelope (binding): no modem/vendor-partition writes, no WiFi configuration changes, no cron (procd only), additive reversible scripts under the proxy data directory, rollback snapshot before deployment, health gate GREEN around every deploy.

## User Stories

1. As the household owner, I want a forecast of when the Samantel package will run out, so that I can slow usage before we are cut off mid-month.
2. As the household owner, I want tiered alerts (warn / urgent / exhausted) instead of raw numbers, so that I only act when it matters.
3. As the household owner, I want a `/budget` card showing remaining GB, drain rate, projected exhaustion date, and projected cost, so that I can check on demand.
4. As the household owner, I want budget alerts gated by a cooldown, so that the same condition doesn't ping me every hour.
5. As the household owner, I want the exhausted alert to fire immediately regardless of cadence, so that "we are out" is never missed.
6. As the household owner, I want the Friday digest to combine usage, cost, outages, signal, and balance in one card, so that I get the week's story at a glance.
7. As the household owner, I want top devices listed in the digest, so that I know who consumed the week.
8. As the household owner, I want weekly outage minutes in the digest, so that bad weeks are visible without digging through logs.
9. As the household owner, I want current RSRP/operator and uptime in the digest, so that signal trends reach me weekly.
10. As the household owner, I want remaining package GB and its projected exhaustion inside the digest, so that the week sits in the month's context.
11. As the household owner, I want a `/outages` command, so that I can pull outage evidence whenever I want, not just Fridays.
12. As the household owner, I want outages totaled per Jalali month, so that I can claim "MCI owed me 3h40m this month".
13. As the household owner, I want each outage's start/end/duration listed, so that the evidence card is concrete.
14. As the household owner, I want the ledger to distinguish "no usable internet" from routine node rotation, so that VPN hiccups don't inflate my SLA claim.
15. As the household owner, I want monthly consumption attributed per person across all their devices, so that the bill is fair.
16. As the household owner, I want months reported in the Jalali calendar with Persian month names, so that reports match how the family thinks about time.
17. As the household owner, I want to assign a device to a person from the bot, so that corrections don't require SSH.
18. As the household owner, I want to reassign or unassign devices later, so that ownership changes (new phone, sold laptop) stay true.
19. As the household owner, I want unowned devices aggregated as "unassigned", so that per-person numbers always reconcile with the total.
20. As the household owner, I want the monthly people report to send automatically on the first Friday after each Jalali month-end, so that I never have to remember to ask.
21. As the household owner, I want `/month` for any recent Jalali month on demand, so that I can settle disputes about last month.
22. As the household owner, I want per-person totals split into GB and Toman, so that cost sharing is computable.
23. As the household owner, I want the per-owner rollup written permanently before daily files prune, so that a completed month stays computable weeks later.
24. As the household owner, I want a `/wifi` command that sends a QR photo, so that guests join by scanning once.
25. As the household owner, I want a clear fallback message when WiFi credentials aren't provisioned, so that `/wifi` never fails silently.
26. As a guest, I want to scan one QR code to join the household WiFi, so that I don't type a password.
27. As the household owner, I want research findings on whether the vendor natively supports a guest SSID, so that a future guest network decision is grounded instead of guessed.
28. As an implementing agent, I want Jalali conversion as pure functions with known-answer tests, so that calendar math cannot silently corrupt reports.
29. As an implementing agent, I want the outage ledger schema append-only and fixture-testable, so that pairing/totals are provable offline.
30. As an implementing agent, I want runner scripts to take store paths from environment overrides, so that tests never touch the live router.
31. As an implementing agent, I want the watchdog integration to be thin glue around an already-proven probe loop, so that ledger failures cannot break operator switching.
32. As an implementing agent, I want everything deployed through the existing push/procd/health-gate pattern, so that rollout matches house convention and stays reversible.
33. As the household owner, I want all of this to change nothing about how traffic is routed, so that the family internet risk stays zero while reports improve.

## Implementation Decisions

- All new decision/aggregation logic lives in the shared pure-function library as functions taking explicit inputs and emitting key=value or row output — the deep-module pattern established by the link/probe/telemetry seams and consistent with ADR-0005 (derived values, never new sensors).
- Jalali↔Gregorian conversion (both directions plus month-range and Persian month labels) is implemented in jq, which is already deployed on the device and present on the host; validated against reference dates (e.g., 2026-08-22 ↔ 1405-06-31).
- Exactly one new storage seam: the **Outage Ledger** — an append-only transition log (`epoch|kind|detail`) fed by thin glue in the operator watchdog's existing direct-probe state transitions; pairing into durations and monthly totals happens on read. It records "no usable internet" periods, not tunnel-node rotations, matching the SLA framing.
- The Data Budget Guardian derives from the existing balance report cache and the already-unit-tested forecast/budget-decision functions; default thresholds as listed in the Solution; alert emission goes through the existing cooldown registry and Telegram notify path; checks ride the hourly telemetry tick and the daily roll — no new service loop.
- The Weekly Digest replaces the Friday weekly-bill send inside the usage roll, preserving the week-marker gating so it fires exactly once; it composes usage day-files, outage-ledger totals, balance fields, and the newest telemetry row.
- Ownership: a root-only device config maps MAC → person; at roll time a permanent per-owner daily total is appended (before the 35-day day-file prune), keyed by Gregorian date so any Jalali month range can be summed via the calendar module; unowned MACs aggregate under a single "unassigned" person.
- The monthly per-person report triggers on the first Friday at/after a Jalali month boundary (piggybacking the digest send); `/month` accepts an explicit Jalali month within retention.
- `/wifi` reads SSID/passphrase from a root-only device conf provisioned once during implementation; the QR PNG is produced by a static qrencode installed via opkg on the X28 (fallback: pushed arm64 binary + libqrencode with LD_LIBRARY_PATH); the bot uploads the photo multipart through the socks proxy; missing binary or creds degrade to an explanatory card.
- Bot surface grows by: `/budget`, `/outages`, `/digest`, `/month` (+`/people` alias), `/owner` assignment flow, `/wifi`; Panel gains buttons where they fit the existing grid; every reply follows the established Card anatomy.
- Deployment rides the existing deploy script (stdin-push over SSH, init scripts enabled, restart), with a rollback snapshot taken beforehand and the health gate verified GREEN after; rc.local and cron remain untouched.
- The vendor guest-SSID ticket is read-only research: locate SSID persistence (config files vs partitions), enumerate web-API commands used by the vendor UI, and report whether a native guest toggle exists — no settings changed under any circumstance.

## Testing Decisions

- Tests assert external behavior only: card text lines, paired outage durations, tier decisions, Jalali known-answer values, per-person aggregates — never awk/jq internals or file-layout details.
- Pure logic is tested at the shared-library seam (prior art: the hnlib test file with ~77 assertions covering forecast/budget/cooldown).
- Bot formatting and the WIFI-URI builder are tested at the bot library seam (prior art: panel/cards/help/random-MAC tests).
- Runner scripts take store paths via environment overrides; tests feed fixture directories and fixture logs (prior art: telemetry-store tests and the forecast fixture test).
- New test groups: Jalali known-answer conversions; budget tiers incl. immediate-exhausted bypass; outage pairing/totals across month boundaries; digest composition from fixtures; per-person aggregation incl. reassignment and unassigned bucket; wifi URI escaping + graceful degradation.
- Watchdog glue, qrencode installation, and deployment are verified by smoke checks and the health gate, not unit tests.

## Out of Scope

- Creating, renaming, or removing SSIDs; VLANs; any wireless or bridge configuration change on the X28 — pending the research ticket's outcome; real second SSIDs would land on the recovered AX3000T later.
- Network routing tiers (direct/unfiltered per-device rules) — explicitly skipped this round by decision.
- Kill-switch toggle, guided incident flows, modem SMS reader, multi-admin roles — deferred discovery ideas, untouched.
- Router API and Android app changes (the app is frozen per ADR-0004); web dashboard changes.
- Changes to billing rates, Samantel automation internals, fail-open semantics, or the transparent-proxy chain.
- Backfilling outage history before the ledger exists — early weeks will under-report.
- Any cron-based scheduling; any secret committed to the repo.

## Further Notes

- Vocabulary follows CONTEXT.md: Card, Alerts, Link, Remain counters, Data plan, Toman, Telemetry log, Network Event. The Outage Ledger is a derivative of the Network Event concept scoped to the X28 (which today records no events at all).
- Planned ticket order (for `/matt-to-tickets`): 01 Jalali module → 02 Budget Guardian → 03 Outage Ledger → 04 Weekly Digest → 05 People/Jalali monthly + owners → 06 WiFi QR → 07 vendor SSID research → 08 snapshot + docs.
- When terms settle (Outage Ledger, Owner, Jalali report), add them to CONTEXT.md via `/domain-modeling`.
- The glossary's "Router"/nlbwmon entries describe the AX3000T era; everything here is X28-side conntrack accounting and must not touch that legacy system.
