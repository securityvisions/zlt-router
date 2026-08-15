# ADR-0010: Forecasting and insights

**Status**: Accepted (wayfinder ticket #12)

## Context

The vision wants fatigue-free estimates: package exhaustion date, end-of-month usage, end-of-month cost, person quota exhaustion, account balance depletion; plus non-decorative insights (usage vs last month, top person, projected run-out, devices discovered, spending vs average). Existing seams: `ChartMath.projectedExhaustion`, `PackageInsights.dailyConsumption`, daily ledger usage.

## Decision

- New pure objects `Forecasting` and `Insights` (tested like `ChartMath`), no Android dependencies:
  - **Package exhaustion**: extends `PackageInsights` — daily consumption from package snapshots → exhaustion = remain/rate (+ Jalali date label).
  - **Month-end usage**: linear run-rate — `usageSoFar / daysElapsed * daysInJalaliMonth`, from the current month's `daily_usage`.
  - **Month-end cost**: month-end usage × person effective rate (the `Pricing.resolveRate` seam) summed.
  - **Quota exhaustion** (person): person run-rate → days to quota (null when no quota/rate ≤ 0).
  - **Balance depletion**: existing `ChartMath.projectedExhaustion(series)` surfaced with a Persian estimate label.
  - All forecast values render with an explicit «برآورد» (estimate) marker.
- Insights v1 (each a rule with a Persian sentence, rendered in one widget + per-person card):
  - usage change vs previous Jalali month (±%)
  - top person this month
  - package projected to run out before/after expiry (early-danger flag)
  - devices discovered this month (from `activity_events`)
  - spending vs 3-month average
- Monthly usage by person rides the existing ledger reconciliation (no new aggregation).

## Consequences

- Linear run-rate is the honest model — no curve-fitting; the estimate label is mandatory.
- Insights are generated, not curated; the rule set lives in one small enumerated object.