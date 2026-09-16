# ADR-0007: Device is canonical; repo is pull-backup with drift alarm

Date: 2026-09-16 · Status: accepted · Deciders: parsa + agent

## Context

`router/` holds copies of live device configs (sing-box, mihomo, dns-fix.sh,
probe-service.sh, axproxy.nft, proxy-watchdog.sh). Two beliefs collided during
the Sept 16 outages:

- the repo behaved as if it were the source of truth (edits made repo-first,
  then pushed);
- emergency fixes were made device-first (ssh + sed), leaving the repo stale.

Neither belief was enforced by tooling, so the copies silently diverged. That
divergence directly caused three of the night's incidents: probe-service.sh
carried a dead port (1070 vs live 1080), dns-fix.sh diverged after a device-side
hotfix, and the sing-box flow mismatch between device and VPS took the tunnel
down.

## Decision

1. **The device is canonical.** AX3000T and X28 hold the live truth for their
   configs and daemons. The repo is a **pull-backup with a drift alarm**, never
   a push-source for those files.
2. **Every device-side emergency hotfix must be pulled back into the repo in
   the same session** (`netpull`), or the divergence is a bug in the session,
   not a state.
3. **`netpull` must never push.** Pushing a repo copy over a device config is
   forbidden without an explicit per-file override, because the device may hold
   newer hotfixes the repo has never seen.
4. **Drift is an alarm, not an error.** repo ≠ device means "someone changed
   something, and it wasn't recorded" — surface it in `netpull status`, don't
   auto-resolve it in either direction.
5. Shared health-check logic is exempt from this rule: consolidation happens
   repo-first (probe seam, ADR pending effects on Candidate 2), because scripts
   like probe-service.sh are *authored* in the repo and deployed — the
   device-canonical rule covers *device-owned configs*, not repo-authored tools.

## Consequences

- `deploy.sh`'s "never deploy mihomo-config.yaml" comment stops being a wart —
  it is now the documented policy for device-owned files.
- A new `netpull` module (pull + status/diff + manifest) is required; the
  existing `x28-drift.sh` (device-side-only hashing) becomes one input to it,
  not the whole answer.
- AX3000T files with no repo copy (proxy-watchdog.sh) must be pulled once to
  close the gap.
- "Repo-first refactors" must end with a pull-back merge of any device-side
  state, or skip the push entirely for device-owned files.
