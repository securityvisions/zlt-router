# 01 — Data snapshot layer (JSON writer)

**What to build:** A procd service (`x28-dash-data`) that runs every 60 seconds, calls existing read-only scripts (x28-status.sh, x28-health.sh, ledger query, rescue status, link state), converts their output to JSON, and writes atomic snapshot files to `/data/proxy/dashboard/data/`. If any script fails, the previous JSON stays on disk. Zero mutations — purely reads existing state and writes new files.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [ ] Procd service runs every 60 s; each snapshot written atomically (tmp+mv)
- [ ] JSON files: status.json, health.json, budget.json, ledger.json, devices.json, outages.json, rescue.json, link.json
- [ ] Script failure → stale file preserved, error logged, no crash
- [ ] All output is valid JSON (verified with jq after generation)
- [ ] Deployed on X28 as procd service; files verified with `jq . <file>` for each
