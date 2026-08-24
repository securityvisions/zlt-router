# 05 — Weekly Telegram ledger backup

**What to build:** Every Friday the day-roll path tars the ledger history (daily owner files, rollups, billing rates) — a few hundred KB — and sends it as a document to the owner's Telegram chat via a new file-upload helper, on its own week-marker so it fires once a week. A dry-run mode builds the archive and prints what it would send without sending.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [x] Telegram lib gains a document-upload helper (multipart file send)
- [x] Backup script builds the archive from ledger history + rollups + billing config
- [x] Fires at most once per ISO week via its own marker, invoked from the Friday branch of the day-roll
  - _Implementation note:_ the invocation sits on the daily roll path, gated by the ISO-week marker (more robust than the Friday-20:00 branch, which never fires since rolls happen at midnight). The first roll after an ISO-week boundary sends the archive — i.e. Monday 00:00, closing out the prior week.
- [x] Dry-run mode: archive built and described, nothing sent
- [x] Fixture test: archive contains the expected files; marker prevents double-send within the same week
