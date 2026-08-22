# 04 — Admission loop: convert → provider hot-reload → top-N residency

**What to build:** Rescue loop stage: convert raw cache → candidates; cap residents at the churn budget (10); write provider file atomically; hot-reload via controller `PUT /providers/proxies/rescue-pool`; read back per-node health; engine-native verdicts only. On/off master flag persisted at `/data/proxy/rescue/enabled`.

**Blocked by:** 02, 03.

**Status:** resolved

- [ ] Provider hot-reload reflected in controller (node list matches file)
- [ ] Resident cap enforced; converter drops beyond cap deterministically
- [ ] Disabled flag freezes admission (file untouched) and supervisor ignores rescue
