# 26 — Backup/restore + JSON/CSV export

**What to build:** A pure JSON backup of all financial and domain data with a version-gated restore, PIN-confirmed, that never contains the token, PIN, or last snapshot. JSON and CSV export both gain payments.

**Blocked by:** 18 — Room v5→v6 migration spine

**Status:** resolved (BackupCodec version-gated + sanitize + tests)

- [ ] Backup codec round-trips domain data; token/PIN/last-snapshot are excluded.
- [ ] Restore rejects unknown schema versions and requires PIN confirmation.
- [ ] CSV and JSON export include payments.
