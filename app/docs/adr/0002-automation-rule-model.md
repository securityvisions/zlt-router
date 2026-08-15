# ADR-0002: Automation rule model — serializable WHEN/IF/THEN

**Status**: Accepted (wayfinder ticket #4)

## Context

The vision requires automation rules (package low, person over usage/quota, unknown device joins, month end, unpaid bill after N days, balance low) with a visual builder, enable/disable, and run history. Rules must survive restarts, be versionable, and grow.

## Decision

- Room table `automation_rules`: `id` (TEXT PK), `name`, `enabled` (INT), `whenJson` (TEXT — serialized condition), `thenJson` (TEXT — serialized action), `lastRunAt` (LONG), `runCount` (INT), `lastResult` (TEXT nullable), `lastError` (TEXT nullable), `createdAt` (LONG).
- kotlinx.serialization sealed classes, versioned JSON envelope (`{schemaVersion: 1, payload: {...}}`):
  - `AutomationCondition`: `PackageRemainingPctBelow(pct)`, `PackageDepleted()`, `PersonUsageAbove(personId, gb)`, `PersonQuotaPctAbove(personId, pct)`, `UnknownDeviceJoined()`, `ProxyDown()`, `ProxyUp()`, `RouterOffline()`, `BillUnpaidForDays(personId, days)`, `AccountBalanceBelow(toman)`, `MonthEnded()`, `DiskHigh(pct)`.
  - `AutomationAction` v1: `NotifyInbox(title, body)` — writes an inbox event (+ respects the notification toggle for push). Extensible sealed class.
- Evaluation: pure `AutomationEngine.evaluate(rule, context)` — context carries the domain facts (RouterSnapshot, packages, current-month usage by person, quotas, unpaid state, device set, today). Runs once per poll cycle after `SnapshotPollingCycle`, and on app foreground. Fires when a condition transitions false→true (previous boolean stored in `lastResult`); monotonic conditions re-fire only on a new crossing.
- The "bill unpaid for 7 days" condition depends on the Payments model's unpaid computation — the context supplies it; no rule coupling.

## Consequences

- Automation is data-driven (no new code per rule type beyond the sealed classes) and fully unit-testable at the evaluator seam.
- Rule vocabulary grows by adding sealed subtypes; old JSON with `schemaVersion` still decodes (unknown subtypes skipped).
- The builder UI is a form over the sealed classes (dropdown per WHEN type, fields per subtype).
