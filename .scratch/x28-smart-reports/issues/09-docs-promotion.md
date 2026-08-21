# 09 — Docs promotion

**What to build:** The paper trail catches up with what shipped. CONTEXT.md's glossary gains the new first-class terms settled by this batch — Outage Ledger, Owner, Jalali report — defined in the existing glossary style. PRODUCT_DISCOVERY_X28.md marks the shipped discovery ideas. README/docs reflect the new bot commands (`/budget /outages /digest /people /month /owner /wifi`) and the new stores (Outage Ledger, owner config, per-owner rollups). No behavior changes.

**Blocked by:** 02, 03, 04, 05, 06, 07 — documents only what actually shipped.

**Status:** resolved

- [x] CONTEXT.md glossary entries added for Outage Ledger, Owner, Jalali report (with _Avoid:_ lines where the existing style uses them) — plus Budget Guardian, Weekly Digest, WiFi share
- [x] PRODUCT_DISCOVERY_X28.md top-5 table annotated with shipped status — new "Shipped — x28-smart-reports" section with 7 items
- [x] Bot command reference and store layout updated wherever the current commands are documented — CONTEXT glossary, bot help, README/docs via this ticket
- [x] Full suite + web typecheck green; commits follow house convention — suite OK, `tsc -b` 0

## Comments

All behavior tickets (01–08) are required. No new stores beyond those already documented in the batch.
