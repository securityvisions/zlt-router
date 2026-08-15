# ADR-0003: Quotas are informational

**Status**: Accepted (wayfinder ticket #5, chart-time fork: informational)

## Context

The vision wants per-person monthly quotas with progress display, threshold alerts (warn/critical), and quota-exhaustion forecasts. The chart-time fork locked: **informational** — no billing impact, no surcharge.

## Decision

- `PersonEntity.quotaGb: Double? = null` (null = no quota). No group-level quota in v1 (groups are free text today; a group entity is out of spine scope).
- Global threshold prefs in `Store`: `quotaWarnPct = 80`, `quotaCriticalPct = 95`.
- Quota progress = the person's current Jalali month usage (the `LedgerAggregation` seam) / quota.
- Threshold crossing (warn, then critical) writes an inbox event + activity event and may post a local notification per the existing notification pipeline. Deterministic diff, like the package-LOW alert.

## Consequences

- No billing-semantics change; the ledger math is untouched by quotas.
- Quota-exhaustion forecast reuses the run-rate seam (ADR-0010).
- Alerting reuses the poll-cycle/notification pipeline rather than a new one.
