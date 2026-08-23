# 01 — Device-granularity rollups + one-shot backfill

**What to build:** Owner history becomes device-granular so breakdowns and corrections are computable: daily rollups move to `owners-d/YYYY-MM-DD` lines (`person|mac|up|down`), written by the nightly roll before pruning. A one-shot backfill converts the existing ~35 days of per-device day-files through the current owners mapping into that same format — idempotent, safe to rerun, hostname-fallback for unknown MACs (unassigned bucket), and a summary of what it converted. After it runs, today's ledger has weeks of real history instead of "no data yet".

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] Nightly roll writes device-granularity rows (person resolved at roll time, MAC preserved)
- [ ] Backfill converts every existing day-file ≤35 days old; skips dates already backfilled (marker); rerun changes nothing
- [ ] Unknown/absent MACs land in the unassigned bucket, never dropped silently
- [ ] Fixture tests: multi-person, multi-device-per-person, unknown-MAC, idempotent rerun
- [ ] Deployed on the X28; backfill executed once live; counts reported (days converted, rows written); health gate GREEN
