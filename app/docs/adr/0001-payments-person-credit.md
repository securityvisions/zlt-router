# ADR-0001: Payments as first-class records with person credit

**Status**: Accepted (wayfinder ticket #3, chart-time fork: person credit)

## Context

The ledger stores payment as an aggregate `paidToman` on `LedgerEntryEntity` plus a `paid` boolean. The product vision requires multiple part-payments per bill (amount, date, method, note), per-person payment history, overpayment as person credit applied to future months, and exportable payment records. The ledger re-projects months via `LedgerReconciliation` and must not lose payment data when it rewrites entries.

## Decision

- New Room table `payments`: `id` (TEXT PK), `personId` (TEXT, indexed), `entryKey` (TEXT nullable — the ledger entry/month a payment targets), `amountToman` (LONG), `paidAtUnix` (LONG), `method` (TEXT, default `"cash"`), `note` (TEXT, default `""`).
- `PersonEntity` gains `creditToman: Long = 0` — the person credit balance.
- A payment that exceeds the target month's unpaid automatically moves the excess into `person.creditToman`. Credit is auto-applied oldest-unpaid-first in month projections (pure math, unit-tested).
- Migration v5→v6: create `payments`, add `creditToman` to `persons`. Existing `ledger_entries.paidToman` values migrate into one synthetic `payments` row per entry (`id = "migration:<entryKey>"`, `paidAtUnix = 0`).
- `LedgerReconciliation` no longer carries `paidToman`/`paid` in `ReconcileLine`; payment data lives in `payments` and survives re-projection untouched. Manual fields (`costOverride`, `note`, `edited`) stay on the entry.
- Read model: `LedgerAmounts(owed, collection, credit)` — collection = payments for the month + applied credit. Payment status extends to `OVERPAID` (unpaid == 0 && collection > owed). `LedgerPaymentStatus.PAID/PARTIAL/UNPAID/OVERPAID`.
- Merging persons transfers `payments` rows to the survivor; archiving keeps them.
- Backup/export include `payments` and `creditToman`.

## Consequences

- Billing surfaces (ledger UI, messaging, reports, audit) derive amounts from payments + credit through one pure seam.
- Room schema v6; the migration is tested against committed schemas.
- The old `paidToman` column stays on `ledger_entries` (retained for the migration source and read-model fallback) but is no longer written by new flows.
