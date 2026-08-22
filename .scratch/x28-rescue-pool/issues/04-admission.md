# 04 — Admission loop: convert → provider hot-reload → top-N residency

**What to build:** Rescue loop stage: convert raw cache → candidates; cap residents at the churn budget (10); write provider file atomically; hot-reload via controller `PUT /providers/proxies/rescue-pool`; read back per-node health; engine-native verdicts only. On/off master flag persisted at `/data/proxy/rescue/enabled`.

**Blocked by:** 02, 03.

**Status:** resolved

- [ ] Provider hot-reload reflected in controller (node list matches file)
- [ ] Resident cap enforced; converter drops beyond cap deterministically
- [ ] Disabled flag freezes admission (file untouched) and supervisor ignores rescue

## Comments (implementation findings)

- mihomo SAFE_PATHS: provider path must sit under engine home → payload lives at `/data/proxy/mihomo/rescue-pool.yaml` (converter/admission constants updated accordingly).
- Provider payload shipped as single-line JSON — valid YAML subset, jq-safe emission from untrusted strings.
- First real admission: 300 raw URIs → 46 candidates hot-reloaded via `PUT /providers/proxies/rescue-pool`; supervisor HOLD while all candidates dead (by design).
