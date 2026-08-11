# 12 — Notifications

**What to build:** The WorkManager 15-min background poll and local notifications for all seven triggers (balance-tier escalation, new device, proxy transition, high drain, disk >85%, reboot, monthly bill ready), each with a toggle in Settings. Rebooting the router gets a phone notification while the app is closed.

**Blocked by:** 02, 04, 05, 06, 08

**Status:** ready-for-agent

- [ ] Background poll every 15 min while the phone is on the home network
- [ ] All seven triggers post local notifications with per-trigger toggles
- [ ] Trigger diff logic is unit-tested (first poll baselines silently)
