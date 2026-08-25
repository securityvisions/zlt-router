# Drill log — 2026-08-25 (ticket 01, x28-insights-fairness)

Live rollback drill against the dashboard service, executed after this
snapshot's capture. Transcript condensed from the session log.

## Phase 0 — pre-state
- :8080 listener present, page HTTP 200.

## Phase 1 — stop + remove
- `/etc/init.d/x28-dashboard stop`; init + rc.d symlink removed.
- FINDING: listener SURVIVED — pid 5681, `/usr/bin/mini_httpd -C /tmp/mini_dash.conf`,
  orphaned outside procd tracking (daemonize-and-escape; unflagged start).
- Remediation: canonical init fixed to `-D` (foreground); orphan killed.

## Phase 2 — zero trace
- No :8080 listener; curl → 000 (connection refused); vendor :80/:443 → 200/200.

## Phase 3 — redeploy from repo canonicals
- Init pushed from repo copy, enabled, restarted. New mini_httpd bound :8080, page 200.

## Phase 4 — managed-state proof
- `stop` NOW removes the listener (procd controls the process with -D).
- Restart restores service. This is the regression test_dashboard_init.sh guards.

## Phase 5 — post-drill smoke
- page 200 · api/status.json 200 · vendor80 200 · vendor443 200
- X28_HEALTH_GROUPS=dash → PASS/PASS, HEALTH GREEN, rc=0

## Tarball-route restore proof (same day)
- Device-side dry run: tarball extracted to /tmp/restore-proof — 156 files,
  secrets present (proxy config, tg/samantel confs, v2raya db),
  sampled files sha256-IDENTICAL to live copies; proof dir cleaned.
- Note: an initial "DIFFERS" reading was an artifact of the probe script
  (local-shell expansion of the loop variable), not of the archive.
