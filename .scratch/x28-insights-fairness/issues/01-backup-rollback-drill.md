# 01 — Restore point: full-state backup + rollback drill

**What to build:** Before any batch work touches the device, take a complete snapshot of the running custom stack (all scripts, init units, dashboard files, configs — same ritual as the Aug 21/22 rollback snapshots) into the repo's backup area, prove it's complete, and run one live rollback drill on an existing additive service (stop → remove init → confirm zero trace → redeploy from repo). This converts "the process is safe" from a promise into a demonstrated fact, and closes the rollback checkbox left open by the 2026-08-25 dashboard-outage fix.

This ticket gates every other ticket in this directory: no device changes until a verified restore point exists.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [x] Full-state snapshot captured and spot-checked against the live device (file lists + checksums)
- [x] Restore procedure written down (exact steps, tested order)
- [x] Rollback drill executed once on the existing dashboard service: stop + remove init = zero trace, then restored from canonical repo copies
- [x] Post-drill smoke green: page/API 200, vendor :80/:443 untouched, health-gate dash slice GREEN
- [x] Open rollback checkbox on the dashboard-outage issue ticked with evidence

## Answer

Done 2026-08-25, with one significant find the drill was designed to catch.

**Snapshot**: new repeatable tool (`x28-snapshot.sh`, manifest/verify/capture modes; contract fixture-tested in tests/test_snapshot.sh). Captured `router/x28/backup/rollback-20260825-2011/` — 156 files (scripts, init units, dashboard, usage/ledger data, firewall/routing/service state dumps), self-verify OK, 6/6 independent spot-checks against device-computed hashes. Secrets (proxy config, tg/samantel confs) live only in the root-only device tarball `/data/proxy/backup/rollback-20260825-2011.tar.gz` (220 KB); repo copy is secret-free. RESTORE.md generated. A first capture (1914) was superseded and deleted so no one restores the pre-fix init.

**Drill**: stop + remove init reached zero trace (no :8080 listener, curl refused, vendor :80/:443 untouched), then redeployed purely from canonical repo copies.

**Finding**: mini_httpd daemonizes when started without `-D` — it escaped procd tracking, and `stop` left an orphan serving :8080 (this is also why the service looked healthy while unmanaged since Aug 23). Fixed in the canonical init (`-D` foreground) and proven managed: `stop` now removes the listener, restart restores it. Regression spec added (tests/test_dashboard_init.sh), including a detection-power check against the old form.

Post-drill smoke: page/api/vendor 200s, health-gate dash slice GREEN.

Review-pass addenda (same day): the restore doc no longer hand-cites a file count (the drift the review caught) — `verify` is the single source of truth. The tarball route was exercised end-to-end on-device: extract to /tmp, secrets present (proxy config, tg/samantel, v2raya db), sampled files sha256-identical to live; transcript in the snapshot's DRILL-LOG.md. Post-drill smoke output likewise recorded there rather than prose-only. Scope note: the `-D` behavior change to the canonical dashboard init was a drill finding and is owned by x28-dashboard issue 02 (comment + regression test live there); this ticket records it as evidence.
