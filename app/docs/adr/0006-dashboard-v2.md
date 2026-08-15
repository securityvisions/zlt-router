# ADR-0006: Dashboard v2 — widgets, sizes, quick actions

**Status**: Accepted (wayfinder ticket #8)

## Context

The home dashboard supports order/hide preselected cards but **sizes are dead** (persisted, never applied) and there are only four cards. The vision wants reorder/hide/resize, configurable KPIs, quick actions, and saved layouts without grid clutter.

## Decision

- Widget catalog v1 (each honest against existing data): `collection` (unpaid alert), `ranking` (person usage today), `metrics` (router health), `live` (bandwidth summary → links Live), `package` (top/aggregate package + forecast), `balance` (balance trend mini), `monthly` (this-month usage/cost/unpaid), `unpaid` (unpaid list), `quick` (quick actions row), `insights` (insight cards), `activity` (recent timeline).
- **Sizes are applied**: `small` = label+value only; `medium` = value + one detail line; `full` = detail + chart (where a chart exists). Implemented as a `SizeVariant` consumed by each widget family.
- Quick actions: configurable toggle set — register payment, add person, assign device (bulk), refresh router, open live, toggle proxy. Payment opens the person ledger payment flow; assign device opens the Device workspace.
- Layouts: keep the preset mechanism (daily/billing/troubleshooting) and add user-saved named layouts persisted as a pref JSON list; the active layout = order+hidden+sizes.
- Grid: single-column adaptive (phone) / two-column (≥720dp) with `full` spanning; no free-form drag (order is list-based, sizes are per-card).

## Consequences

- Sizes stop being dead; order/hidden/sizes become the active layout, presets seed it.
- New widgets reuse existing projections (LedgerReadModel, package insights, ChartMath) — no new data pipeline.
- Payment and messaging quick actions light up as those subsystems land.