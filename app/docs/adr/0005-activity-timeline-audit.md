# ADR-0005: Activity timeline + unified billing audit

**Status**: Accepted (wayfinder ticket #7)

## Context

The vision wants a filterable event timeline (person/device/billing/packages/network/alerts) and billing audit (owner changed, rate changed, payment updated). Today only ownership has an audit table (`ownership_audit`).

## Decision

- Two tables with different retention:
  - `activity_events` (timeline): `id` (TEXT PK), `ts`, `kind` (TEXT), `personId?`, `deviceId?`, `packageId?`, `entryKey?`, `details` (TEXT), `source` (TEXT: `poll`/`user`/`system`/`automation`). Pruned after 180 days.
  - `audit_events` (permanent billing audit): `id` (TEXT PK), `kind` (TEXT), `ts`, `personId?`, `deviceId?`, `entryKey?`, `details` (TEXT), `actor` (TEXT default `local`). Never pruned.
- The existing `ownership_audit` table stays as read-only legacy; all new audit entries (ownership, rate, payment, person, ledger edits) write `audit_events`.
- Write helpers: `Audit.record(db, kind, ...)` and `Timeline.record(db, kind, ...)` — one seam used by every mutation and by the poll cycle.
- Timeline kinds: NewDevice, DeviceOwnerChanged, DeviceRenamed, QuotaCrossed, PackageLow, PackageDepleted, PackageExpired, PaymentRegistered, BillGenerated, MonthClosed, AutomationRun, ProxyDown, ProxyUp, RouterOffline, RateChanged, Insight.
- UI: timeline screen with kind/label filters; billing audit surfaced under the person and month detail.

## Consequences

- Audit is permanent (money-related) — feeds the "never destructively migrate the ledger" rule.
- Timeline is prunable and feeds the insights feature ("devices discovered this month").
- Payments/rate changes write audit rows through the unified seam.