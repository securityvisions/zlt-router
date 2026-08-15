# ADR-0004: In-app notification inbox (augments local notifications)

**Status**: Accepted (wayfinder ticket #6)

## Context

The vision wants an in-app inbox with unread/read/acknowledged/muted states covering new device, high usage, package low/expired, router offline, low balance, unpaid bill, automation results. Today notifications are fire-and-forget WorkManager posts; package alerts have a pending queue.

## Decision

- New Room table `inbox_events`: `id` (TEXT PK), `ts` (LONG), `kind` (TEXT — enum name: NewDevice, PackageLow, PackageDepleted, PackageExpired, PackageNew, PackageDisappeared, ProxyDown, ProxyUp, RouterOffline, BalanceLow, BalanceWarn, QuotaWarn, QuotaCritical, UnpaidBill, AutomationResult, PaymentRegistered, DeviceOwnerChanged, RateChanged, System), `title`, `body`, `personId?`, `deviceId?`, `packageId?`, `read` (INT), `acknowledged` (INT), `muted` (INT).
- **Augment, not replace**: poll-cycle events and package alerts that pass their toggle also write inbox rows (in addition to push). Automation `NotifyInbox` writes inbox rows. Billing/device mutations write inbox + audit rows (ADR-0005).
- Per-kind mute lives in `Store` (the existing per-toggle prefs map to kinds); per-row `muted` is for future per-entity mute.
- UI: inbox screen with unread count badge, filter by kind, mark-read, mark-acknowledged.

## Consequences

- One write interface (`InboxKeeper.record(...)`) used by the poll cycle, automation, and mutations.
- Inbox rows participate in backup/restore and the activity timeline (they are event sources).
