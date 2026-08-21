# 02 — ProbeService seam

**What to build:** The 7 probe isolates (generate_204 vs instagram vs 1.1.1.1 vs ipify with 5 timeouts) collapse into one `ProbeService` with `ProbeProfile` per Link / PassWall / VPS origin and a single `ProbeService.check()` budget — adding a `via_x28` node no longer means editing 3 probe lists, and `dns-fix.sh:tunnel_ok` vs `x28-vps-heal.sh:mihomo_auto_dead` become the same question.

**Blocked by:** 01 — LinkState seam

**Status:** resolved

- [x] `ProbeService {cheap:204, passive:telemetry delta, sample:10MB}` + `ProbeProfile` per context, single `PROBE_URL`/`TIMEOUT` env, unified `check()` used by `dns-fix.sh`, `x28-vps-heal.sh`, `snap.sh`.
- [x] Adding a new PassWall node requires no probe-list edit.
- [x] Health gate stays GREEN after deploy.
