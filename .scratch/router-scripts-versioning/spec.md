# Router Scripts Versioning + Deepening — spec

The repo tracks 11 of the 17 scripts that run on the router. Seven modules exist only on the
router — `usage.sh` (the most-called module in the system, 10+ call sites), `friday.sh`,
`hyst.sh`, `monthly.sh`, and the three PassWall health scripts (`passwall-failopen.sh`,
`passwall-autorecover.sh`, `passwall-bypass-ensure.sh`) — and three versioned scripts have
drifted from their deployed copies (`balance.sh`, `routerapi.sh`, `routerapi_lib.sh`).
Architecture review (2026-08-15) surfaced this as the top governance gap: an agent reading the
repo sees ten call sites of an invisible module and must reconstruct its behavior from call sites.

This effort has two phases:

## Phase 1 — version the router system (ticket 01)

Bring every router-only script into `router/` as the canonical copy (same deal as hnlib/botlib:
repo copy deploys to the router), re-sync the drifted copies, and record the deployment map so
the repo is the single source of truth for the whole system.

## Phase 2 — deepen the seams (tickets 02–05)

With the whole system versioned, deepen the known friction points from the architecture review:

- **System-state module (02)**: one `hn_sys_state` reader for load/mem/temp/disk/uptime/proxy/
  nlbw, replacing the API's seven one-line `ra_*` readers, the bot's inline re-reads
  (botcmd.sh:113-126), snap.sh's probe, and tg.sh's disk parse.
- **usage.sh contract tests (03)**: pin the six-flag CLI contract (`--today --raw --month
  --names --name --resolve`) with fixture-based tests.
- **Balance field accessor (04)**: kill the byte-identical nine-line `sed` field extraction
  duplicated in botcmd.sh and routerapi_lib.sh.
- **Balance series reader (05)**: one `hn_balance_series [days] [format]` for the bot's
  sparkline (14 points) and the API's history endpoint (90 points).

## Principles

- Every script that runs on the router has a canonical copy in `router/` (tests source it).
- Shared readers live in `hnlib.sh` behind `key=value` or `|`-delimited interfaces (the
  `hn_balance_fields` pattern) so callers never re-implement parsing.
- Tests use the fixture-override trick already proven in `router/tests/lib.sh` (env-var paths).
- Deployability is documented: `router/` → `/root/`, `routerapi*` → `/www/cgi-bin/`.
