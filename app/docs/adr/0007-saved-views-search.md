# ADR-0007: Saved views + global search

**Status**: Accepted (wayfinder ticket #9)

## Context

The vision wants saved filters (unpaid users, unknown devices, usage > 50 GB, offline devices, IoT, guests, high consumption) returning quickly, plus global search across people/devices/MAC/IP/packages/notes/months/payments, command-palette style.

## Decision

- Room table `saved_views`: `id` (TEXT PK), `name`, `target` (TEXT: `ledger` | `devices` | `people`), `filterJson` (TEXT — serialized filter object per target: `LedgerMonthQuery`-equivalent or the device-workspace filter set), `createdAt`, `pinned` (INT).
- Saved views render as a chip row at the top of the Ledger and Device-workspace screens; tapping applies the filter.
- **No FTS for v1**: the dataset is household-sized; global search runs indexed LIKE queries across people, devices (name/alias/MAC/IP/notes), packages (name/alias/id/notes), ledger (notes/months), and payments (notes/method). Command-palette UI: a search overlay from the top bar, results grouped Person/Device/Package/Ledger.

## Consequences

- Search is snappy at this scale without FTS schema complexity; FTS4 remains an option if the dataset grows.
- Saved views serialize the *same* filter model the UI already uses (no new predicate language).