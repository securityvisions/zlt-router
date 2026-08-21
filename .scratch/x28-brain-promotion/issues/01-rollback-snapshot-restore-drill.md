# 01 — Rollback snapshot + restore drill

**What to build:** A complete, restorable snapshot of the X28's current
working state — the undo button every later ticket depends on. The backup
lands both in the repo (`router/x28/`) and as a tarball on the X28's
persistent storage, and the restore procedure is documented and rehearsed
read-only so we know it works *before* anything risky happens.

**Blocked by:** None — can start immediately.

**Status:** resolved (rollback-20260821-0028: 30/30 drill-verified, secrets only in the device tarball; see `router/x28/backup/rollback-20260821-0028/RESTORE.md`)

- [x] Snapshot covers: xray configs, the tproxy enable/disable + DNS-fix
      scripts, `/etc/rc.local`, the net hotplug hook, all custom init
      scripts (operator watchdog, v2raya, crypto engine), the watchdog
      daemon + its log, a dump of the live iptables nat/mangle rules, and
      the generated dnsmasq config with its tunnel upstream line.
- [x] Repo copies land under the canonical x28 area; a dated tarball lands
      on the X28's persistent data volume.
- [x] Restore procedure written down and rehearsed **read-only**: files
      extracted to a scratch dir and checksum-verified against the
      originals — nothing applied.
- [x] Taking the snapshot touches no live service (no restarts, no rule
      flushes); the X28 health state is unchanged afterwards.
