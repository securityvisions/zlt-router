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
- [03 - ProbeService seam for BOTH devices](issues/03-probeservice-seam.md): unified ProbeService with socks5h remote resolution, dual-endpoint fallback, auto SOCKS selection, and delegated callers.
- [04 - Fix CONTEXT.md naming drift](issues/04-context-naming-drift.md): mihomo is the X28 engine, Hysteria2 availability is IP-pool dependent, linkstate location corrected.
- [05 - Repair the Usage Engine Seam & Deterministic Time Injection](issues/05-usage-core-date-seam.md): parameterized month target in `ra_json_usage` and tolerant latest-log fallback in `ra_usage_month_rows`, making entire repo test suite 100% green.
- [06 - Encapsulate Telegram Transport & Format Guarding](issues/06-tg-transport-guard.md): guarded HTML escaping for alert titles, SOCKS proxy auto-discovery, and link-preview suppression in `tg.sh`.
- [07 - Decouple Bot Command Execution from Telegram UI](issues/07-bot-command-dispatcher.md): pure rendering seam `bot_render_card` unifying inline button callbacks and slash commands with zero output divergence.

## Not yet specified

- Drift alarm automation: cron that runs `netpull status` and alerts Telegram on divergence — shape depends on what `netpull status` outputs.

## Out of scope

- Repo-as-canonical deploys of device-owned configs (ADR-0007 forbids).
- Moving the proxy core off the routers to a mini-PC (separate effort — FTTH/minipc strategy doc).
- Probe consolidation for X28's rescue-pool health checks (mihomo-native, works, low value).

## Blocking

- 03 (ProbeService cross-device), 05 (usage-core date seam), 06 (tg-transport), and 07 (bot-dispatcher) are unblocked and ready for implementation.
