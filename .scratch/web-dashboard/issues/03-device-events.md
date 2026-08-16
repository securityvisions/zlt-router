# 03 — Event instrumentation: device lifecycle + security

**What to build:** New-device detection, quarantine, and approval record device lifecycle events. A device joining records `device_joined` (device as actor); quarantine blocking records `device_blocked` (newly-blocked only); `/approve` records `device_approved`.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] devicewatch records `device_joined` with the device as actor.
- [ ] quarantine records `device_blocked` only for newly-blocked MACs.
- [ ] quarantine approval records `device_approved`.
