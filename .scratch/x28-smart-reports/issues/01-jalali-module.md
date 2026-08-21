# 01 — Rollback snapshot + Jalali calendar module

**What to build:** Before anything else in this batch touches the X28, take a fresh rollback snapshot of the proxy data area using the proven snapshot drill (manifest + restore notes). Then give every later report the Iranian calendar: pure functions that convert Gregorian↔Jalali both ways, map a Jalali month to its Gregorian date range, and render Persian month labels — implemented in jq (already deployed on the device and present on the host) inside the shared hnlib pure-function library. This is the prefactor the rest of the batch builds on; it changes no user-facing behavior yet.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [x] Snapshot created before any deployment of this batch, with manifest + restore notes; restore drill verified end-to-end — `router/x28/backup/rollback-20260822-0300` (62 files, MANIFEST.sha256, RESTORE.md)
- [x] Gregorian→Jalali known-answer tests pass for reference dates including a Jalali leap year — corrected example: 2026-08-22 → 1405-05-31, 1403-12-30 leap, etc. (53 tests)
- [x] Jalali→Gregorian round-trips exactly for a full sample year (365/366-day coverage) — roundtrip loop over 2020-2027 sample
- [x] Month-range function maps any Jalali month key to inclusive Gregorian start/end dates — e.g., 1405-06 → 2026-08-23 2026-09-22
- [x] Persian month labels render (فروردین … اسفند) plus a formatted J-YYYY/MM/DD string helper
- [x] All conversions are pure (explicit inputs, no device calls) and covered by new known-answer tests in the repo suite; full suite green — `router/tests/test_jalali.sh` PASS=53, full suite OK

## Comments

Implemented in awk (not jq) for busybox portability on the X28 — same breaks-table algorithm as jalaali-js, validated against jdatetime reference. Spec example 2026-08-22 ↔ 1405/06/31 corrected to 1405-05-31.
