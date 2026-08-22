# 02 — Engine landing: provider + rescue + world (behavior-neutral)

**What to build:** One-time live-config edit + template sync: `proxy-providers.rescue-pool` (file-backed, health-check 60 s), group `rescue`, selector `world [auto, rescue]`, final rule `MATCH,world`. World defaults/pinned to `auto` — zero behavior change. Seed provider file with a harmless dead placeholder so the provider validates. Engine config-test passes; controller exposes world/rescue.

**Blocked by:** 01 (placeholder comes from converter output conventions).

**Status:** ready-for-agent

- [ ] Controller shows groups world (selector) and rescue; MATCH targets world
- [ ] With world=auto, traffic behavior identical to before (verified by probes)
- [ ] Breaking the provider file degrades only the pool, never the core
