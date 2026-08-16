# 21 — Payments ledger + person credit

**What to build:** Payments become first-class records (amount, date, method, note). Part-payments are tracked per bill; overpayment becomes credit on the person and is automatically applied oldest-unpaid-first; a bill's status derives as Unpaid / Partially paid / Paid / Overpaid. Closed Jalali months freeze against router changes, and every money mutation writes an audit row.

**Blocked by:** 18 — Room v5→v6 migration spine

**Status:** resolved (PaymentMath + payments table + credit + tests)

- [ ] PaymentMath collection/credit/status matrix is tested (unpaid/partial/paid/overpaid, excess→credit, oldest-unpaid-first, rounding).
- [ ] Ledger UI's payment dialog becomes add-payment over a payments list.
- [ ] Closed Jalali months are frozen; every money mutation writes an audit row.
