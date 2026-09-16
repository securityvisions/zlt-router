# Config Tooling Hardening Map

Label: `wayfinder:map`

## Destination

`netpull` is shipped (status/diff + pull, never push) so repo↔device divergence is always visible and device configs are backed up in one command; ProbeService is the single health-check seam for both devices; the CONTEXT.md glossary matches deployed reality. After that, config/tooling work stops surprising us.

## Notes

- Domain: two-device home network — AX3000T (main router, sing-box/dnsmasq/nftables) and X28 (cellular modem, mihomo under /data/proxy).
- **ADR-0007 (device-canonical, repo = pull-backup, never push) is already settled** — `docs/adr/0007-device-canonical-repo-backup.md`. All tickets must obey it; do not re-litigate repo-as-canonical.
- Skills to consult: `codebase-design` (module/seam/depth vocabulary), `domain-modeling` (CONTEXT.md upkeep), `grilling` (HITL tickets).
- Evidence base: Sept 16 architecture review (HTML report in /tmp, friction report in session) — repo↔device drift caused 3 of 4 outage incidents tonight.
- Standing preference: repo-authored tools (probe-service.sh etc.) deploy device→repo is forbidden per ADR §5; device-owned configs (mihomo-config.yaml) pull-only.

## Decisions so far

- [01 - Build netpull: status, pull, never push](issues/01-netpull.md): netpull shipped with an 11-entry manifest, batched status, pull-only semantics; fixture-tested 10/10 device-free.
- [02 - Pull proxy-watchdog.sh into the repo](issues/02-pull-proxy-watchdog.md): canonical copy pulled from AX3000T; no-canonical gap closed.
- [04 - Fix CONTEXT.md naming drift](issues/04-context-naming-drift.md): mihomo is the X28 engine, Hysteria2 availability is IP-pool dependent, linkstate location corrected.

## Not yet specified

- Lib prelude consolidation (`esc()` ×3, two Telegram senders, per-script loader chains → one `lib/prelude.sh`) — real duplication but no incident forces it yet; graduate when a Telegram API change actually bites, or after the probe seam proves the pattern.
- Drift alarm automation: cron that runs `netpull status` and alerts Telegram on divergence — shape depends on what `netpull status` outputs, so ticket it after ticket 01.

## Out of scope

- Repo-as-canonical deploys of device-owned configs (ADR-0007 forbids).
- Moving the proxy core off the routers to a mini-PC (separate effort — FTTH/minipc strategy doc).
- Probe consolidation for X28's rescue-pool health checks (mihomo-native, works, low value).

## Blocking

- 02 and 04 are unblocked; 01 is the recommended first pull (its manifest decides what 02 covers); 03 is an independent grilling ticket.
