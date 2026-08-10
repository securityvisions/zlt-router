# 04 — Name the active node in proxy UP/DOWN alerts

**What to build:** The proxy monitor's Telegram alerts name the actual active proxy setup (e.g. "Auto (REALITY-443-parsa, Hysteria2)") instead of the stale "Hysteria2" label, while keeping the existing state-change-only alerting, the SOCKS-based probe, and the persisted up/down state file.

**Blocked by:** 03

**Status:** ready-for-agent

- [ ] The alert label is derived from the current TCP node config, handling URLTest member nodes and SOCKS-referenced nodes
- [ ] A state change produces an alert with the correct label
- [ ] No state change still produces no message (no spamming)
- [ ] The probe and state persistence behave exactly as before
