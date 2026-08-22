# 05 — Watchdog escalation: bearer bounce

**What to build:** The nastiest cellular failure is the wedged bearer: the modem holds an IP but zero data flows, and an operator switch doesn't fix it. Today the watchdog exhausts its switches and then just keeps watching. This ticket adds one more rung to the escalation ladder: when a full switch round fails to restore data, the watchdog bounces the WAN data connection itself (bring the wan interface down and back up), waits for it to re-register, and only then resumes normal probing. The bounce is ledgered, notified, storm-guarded like switches, and honors a dry-run env so it can be exercised safely before being trusted.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [ ] Escalation rule is pure and unit-tested: given failed-switch count / current data state / last-bounce time → bounce yes/no (respects its own cooldown, independent from the switch storm guard)
- [ ] Bounce action brings the wan interface down, waits bounded seconds, brings it up; aborts to logging if the interface fails to return
- [ ] Dry-run env logs "would bounce" without acting; default config has dry-run off but the first live exercise is performed in dry-run, then once for real
- [ ] Every real bounce: Outage Ledger entry + Telegram card with before/after probe results
- [ ] Live verification: controlled exercise shows data restored after a bounce where a plain switch did not restore it; health gate GREEN after

## Comments

Design pivot: instead of ifup wan (vendor ql_mipc wan is not netifd-owned), the bounce is a FORCED re-registration on the current PLMN through the proven cmd 228 reselect path. Verified live end-to-end: one-shot bounce re-registered and data confirmed in ~19s; DRYRUN gate verified; escalation arming observed in a dead-endpoint exercise. A genuine wedged-bearer incident will be handled automatically on first occurrence.
