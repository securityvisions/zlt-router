# Spec: Personal ISP & Home Network Operations Dashboard (Xirouter v2)

## Problem Statement

Xirouter is a Persian-first Android companion to a home router. It already tracks people, devices, packages, a Jalali billing ledger (aggregate payments), notifications, live bandwidth, and a customizable dashboard. The product vision is a **premium Personal ISP & Home Network Operations Dashboard**: people-centered usage roll-up, rich billing (part-payments, person credit), automation rules, a message center, quotas, an inbox, an activity timeline, honest forecasts and insights, saved views and global search, backup/restore, and a dashboard whose widgets and quick actions are actually configurable. Today the app is a capable utility, not yet an operations dashboard: payments are a single aggregate number, there is no automation, messaging, quota, inbox, timeline, search, backup, or honest forecast, and dashboard "sizes" are dead settings.

## Solution

Xirouter v2 turns the app into a cohesive operations dashboard, modeled around **people**. Every screen derives from one consistent domain spine (ADR-0001…ADR-0011): payments as first-class records with person credit; quotas as informational progress; automation rules as serializable WHEN/IF/THEN evaluated on each poll; an in-app inbox that augments local notifications; a permanent billing audit plus a prunable activity timeline; device enrichment (IP, last-seen, type, tags, analytics exclusion); a pure JSON backup/restore codec; saved views and command-palette search; message templates shared through the Android share sheet; and a dashboard where sizes, widgets, and quick actions are real.

## User Stories

1. As a household admin, I want each person's monthly usage rolled up from their devices, so that I can see who consumes what without per-device arithmetic.
2. As a household admin, I want to assign and reassign devices to people in bulk, so that I can correct ownership quickly.
3. As a household admin, I want ownership suggestions with reasons and confidence, so that I can assign unknown devices without guessing (never auto-assigned).
4. As a household admin, I want to record a part-payment against a person's bill, so that I can track installments.
5. As a household admin, I want to see every payment for a bill with amount, date, method, and note, so that I can reconcile accounts.
6. As a household admin, I want overpayment to become credit on the person's account, so that money is never lost.
7. As a household admin, I want credit automatically applied to the oldest unpaid bill, so that balances stay correct without manual bookkeeping.
8. As a household admin, I want a bill's status to be Unpaid / Partially paid / Paid / Overpaid, so that I can prioritize collection.
9. As a household admin, I want closed Jalali months frozen against router changes, so that historical bills never shift.
10. As a household admin, I want to set a monthly quota per person with warn/critical thresholds, so that I can see at-risk usage at a glance.
11. As a household admin, I want quota crossings to appear in the inbox and activity timeline, so that I don't have to watch every day.
12. As a household admin, I want automation rules like "package below 15% → notify me", so that routine monitoring is automatic.
13. As a household admin, I want a visual rule builder with enable/disable and run history, so that rules are inspectable and controllable.
14. As a household admin, I want an in-app inbox with unread/read/acknowledged states, so that I can triage alerts when I open the app.
15. As a household admin, I want an activity timeline filtered by person/device/billing/packages/network/alerts, so that I can see what happened and when.
16. As a household admin, I want a permanent audit of billing changes (rate, payment, ownership, edits), so that money changes are accountable.
17. As a household admin, I want to generate a personalized monthly message per person from a template, so that I can bill politely.
18. As a household admin, I want to copy or share a message via SMS/Telegram/WhatsApp through the share sheet, so that I don't retype bills.
19. As a household admin, I want to select unpaid people and generate all their messages at once, so that monthly billing is one flow.
20. As a household admin, I want honest forecasts (package exhaustion, month-end usage/cost, quota exhaustion, balance depletion) clearly marked as estimates, so that I can plan.
21. As a household admin, I want generated insights (usage vs last month, top person, run-out risk, new devices, spending vs average), so that the dashboard tells me what matters.
22. As a household admin, I want a dashboard where widgets reorder, hide, resize (small/medium/full actually changes the card), and quick actions are configurable, so that home shows what I use.
23. As a household admin, I want saved views for filters like "unpaid", "unknown devices", "offline", so that recurring checks are one tap.
24. As a household admin, I want global search across people, devices, MACs, IPs, packages, notes, months, and payments, so that I can find anything fast.
25. As a household admin, I want a backup of all financial and domain data as a JSON file, and a restore that is version-gated and safe, so that history never depends on the router.
26. As a household admin, I want JSON and CSV export (payments included), so that I can keep records outside the app.
27. As a household admin, I want device enrichment (IP, last seen, type, tags) and analytics/billing exclusions, so that privacy is respected per device.
28. As a household admin, I want a person mini-dashboard (usage, estimated cost, payment state, devices, trend, quota progress, previous months), so that one person is understandable at a glance.
29. As a household admin, I want every feature to be Persian-first and RTL-correct with explicit LTR containers for MAC/IP/URLs, so that the app reads naturally.
30. As a household admin, I want consistent loading, error, and empty states across screens, so that the app feels finished.

## Implementation Decisions

All decisions below are locked by ADRs (docs/adr/0001–0011). The build is one spine release: Room schema v5→v6 (explicit migration, tested against committed schemas), then feature surfaces over it.

- **Room v6 migration (one explicit migration)**: adds `payments`, `inbox_events`, `activity_events`, `audit_events`, `automation_rules`, `saved_views`, `message_templates`; adds columns to `persons` (`creditToman`, `quotaGb`) and `device_settings` (`ip`, `deviceType`, `tags`, `lastSeenUnix`, `excludeFromAnalytics`). Migration v5→v6 also seeds synthetic `payments` rows from existing `ledger_entries.paidToman` (id `migration:<entryKey>`) and copies `ownership_audit` into `audit_events` (ownership_audit retained as legacy read-only).
- **Payments (ADR-0001)**: `PaymentMath` pure object — month collection = payments for the month + applied credit (oldest-unpaid-first); overpayment excess → `persons.creditToman`; status derives Unpaid/Partial/Paid/Overpaid. `LedgerReconciliation` stops carrying `paidToman`/`paid`. Ledger UI payment dialog becomes add-payment (amount/date/method/note) over the payments list.
- **Quotas (ADR-0003)**: `persons.quotaGb?` + `Store.quotaWarnPct`/`quotaCriticalPct`; crossing diffed per poll like package-LOW; writes inbox + activity.
- **Automation (ADR-0002)**: sealed `AutomationCondition`/`AutomationAction` (kotlinx, versioned envelope) + `AutomationEngine.evaluate(rule, context)`; fires on false→true; context = snapshot + packages + monthly usage + quotas + unpaid state + devices + today; runs after each poll cycle and on app foreground; NotifyInbox action.
- **Inbox (ADR-0004)**: `InboxKeeper.record(...)` shared by poll events, package alerts, automation, and mutations; per-kind mute via Store toggles; UI screen with unread badge and filters.
- **Timeline + audit (ADR-0005)**: `Timeline.record` (prunable 180d) and `Audit.record` (permanent) seams; existing ownership audit writes move to `audit_events`.
- **Device enrichment (ADR-0009)**: poll updates ip/lastSeenUnix from `/clients`; online = presence; `excludeFromAnalytics` drops the device from ranking/insights/history.
- **Saved views + search (ADR-0007)**: `saved_views` with `filterJson` of the existing filter models; chip rows on Ledger + Device workspace; command-palette overlay with grouped LIKE search (no FTS).
- **Backup/restore (ADR-0008)**: pure `BackupCodec` JSON envelope (domain tables + non-secret display prefs; **never** token/pin/lastSnapshot); restore = version-gated full replace, PIN-confirmed; CSV gains payments; JSON export = envelope.
- **Messaging (ADR-0011)**: `message_templates` (seeded default Persian template); pure `MessageCenter.render` with `{name} {month} {usage} {amount} {remaining} {due_date} {credits}`; copy + share sheet; bulk flow from the Ledger unpaid filter.
- **Forecasting + insights (ADR-0010)**: pure `Forecasting` and `Insights`; linear run-rate; estimates always labeled «برآورد»; five insight rules.
- **Dashboard v2 (ADR-0006)**: widget catalog v1 (collection, ranking, metrics, live, package+forecast, balance mini, monthly, unpaid, quick actions, insights, activity); `SizeVariant` (small/medium/full) actually applied; quick actions (register payment, add person, assign device, refresh, live, proxy); layouts = order+hidden+sizes, presets seed them, user-saved named layouts as pref JSON.
- **Domain vocabulary**: use CONTEXT.md terms (person, device, package, ledger month, ownership interval, rate, credit) throughout; new terms (payment, credit, quota, automation rule, inbox event, activity event, saved view, template, forecast) added to the glossary.

## Testing Decisions

- Test external behavior at the existing pure seams, mirroring current prior art: `LedgerTest`, `ChartMathTest`, `PackageModelTest`, `NotificationEventsTest`, `LiveBandwidthTransitionTest`.
- **PaymentMath**: collection/credit/status matrix (unpaid/partial/paid/overpaid), excess→credit, oldest-unpaid-first application, rounding.
- **AutomationEngine**: each condition fires on the crossing (false→true), does not re-fire while true, respects enable/disable, NotifyInbox writes one inbox row; versioned JSON round-trip with unknown subtypes skipped.
- **MessageCenter**: variable substitution, Persian formatting, missing-variable handling, template round-trip.
- **Forecasting/Insights**: run-rate math, estimate boundaries (no quota → no quota forecast), insight phrasing stable.
- **BackupCodec**: envelope round-trip, token/pin/lastSnapshot excluded, schemaVersion gate, unknown-version rejection.
- **Quota crossing**: warn→critical diff, inbox+activity writes.
- **Migration v5→v6**: androidTest against committed schemas — payments seeded from paidToman, new columns present, ledger rows preserved.
- UI behavior (sizes applied, saved-view chips, inbox filters) is covered by unit tests where pure (filter application) and manual QA otherwise.

## Out of Scope

- Android home-screen widgets (deferred, fog).
- PDF export (deferred; codec design does not preclude it).
- Router-side endpoint implementation (separate repo; the app degrades gracefully and names the 4 true gaps from the API-gap analysis).
- Real last-seen / per-device history from the router (approximate from poll presence until the router repo adds endpoints).
- SMS permission / Telegram bot for messaging (share sheet only).
- Device type auto-inference from MAC OUI.
- Group-level quotas and group entity (groups remain free text).
- Enforced (surcharge) quotas.

## Further Notes

- The vision doc (conversation 2026-08-14) is the product reference; ADR-0001…0011 are the technical authority.
- Every new money mutation writes an audit row; no destructive migration ever touches the ledger.
- Persian-first: all new UI text in Persian; MAC/IP/URLs wrapped in `Format.bidi`.
- The build is expected to proceed through to-tickets into per-ticket implementation with TDD at the seams above.
