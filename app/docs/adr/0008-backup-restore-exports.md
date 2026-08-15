# ADR-0008: Backup/restore + export formats

**Status**: Accepted (wayfinder ticket #10)

## Context

Financial history must never depend only on transient router data. The vision requires local backup, manual export, restore, and future cloud-backup-readiness without building cloud now. Exports: CSV (exists), JSON, PDF "where appropriate".

## Decision

- One JSON envelope for both backup and JSON export, produced by a pure `BackupCodec`:
  `{schemaVersion, exportedAt, data: {persons, devices, ownershipHistory, ledgerMonths, ledgerEntries, dailyUsage, packages, packageSnapshots, payments, inboxEvents, auditEvents, activityEvents, savedViews, automationRules, messageTemplates, personCredit}}`.
  `settings` (Store prefs) are excluded **except** non-secret display prefs; **`token`, `lockPin`, `lastSnapshot` are never exported**.
- Restore: SAF import → validate `schemaVersion` ≤ current → full replace (one transaction: clear + insert), token/PIN untouched (user re-enters). Confirmed by a destructive-action PIN dialog.
- Formats: CSV (existing, extended to payments) + JSON (the envelope). **PDF deferred** (out of scope for this effort; the envelope design does not preclude it).
- Cloud-ready: `BackupCodec` is transport-agnostic (bytes in/out); a future cloud upload calls the same codec.

## Consequences

- One tested codec serves export, backup, and future cloud.
- Restore is explicit and migration-safe (version-gated).
- The ledger's permanence is guaranteed by backup, not by the router.