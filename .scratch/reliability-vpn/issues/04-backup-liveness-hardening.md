# 04 — Backup + liveness hardening

**What to build:** Nightly `tar` of `/data/proxy/mihomo/config.yaml` to `router/x28/backup/` + `x28-health.sh` liveness probe for `mihomo` (`pidof mihomo`) with procd `respawn` — survives `lan_mgr` regeneration and bad deploys.

**Blocked by:** 01 — VPS auto-heal watchdog

**Status:** resolved

- [x] Nightly backup exists in `/data/proxy/backup/` and in repo `router/x28/backup/` (redacted, no secrets).
- [x] `x28-health.sh` checks `pidof mihomo`; procd `x28proxy` has `respawn 3600 5 5`; kill test: `HEALTH: GREEN` after respawn.
