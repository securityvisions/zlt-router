# 06 — tg.sh alerts restyle

**What to build:** The alert messages sent by the monitoring path (device-joined, device-revived, balance notices, disk, reboot) are rendered in the same Card language as the Panel, so the whole bot reads as one product. Alert text keeps its existing meaning and emoji tiers 🟢🟠🔴 — only the anatomy is unified: a compact title, section rule, and aligned value lines, sized to fit Telegram's alert width. Alert composition must not delay or drop the underlying notification.

**Blocked by:** 01 — Card v2 rendering core

**Status:** ready-for-agent

- [ ] Device-joined/revived alerts use the Card anatomy without losing the device name/UR link
- [ ] Balance-tier alerts (notice/warn/urgent) render with the tier badge and aligned numbers
- [ ] Disk and reboot alerts are consistent with the rest
- [ ] The restyle adds no failure path: a rendering error can't suppress an alert that previously fired
- [ ] The monitoring cadence and delivery are unchanged (same schedules, same chat)

## Comments

This is the notification channel kept out of the first Card round; unified now so alerts and Panel replies share one visual language.