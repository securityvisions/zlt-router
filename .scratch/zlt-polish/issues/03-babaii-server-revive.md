# 03 — babaii server revive

**What to build:** `babaii` (`216.45.52.132:23993` VLESS+Vision) — currently `refused` on every port — is rebooted from its hosting console and rejoins `mihomo` `auto` as the third failover node.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] Host `216.45.52.132` shows `ss -tlnp` listeners on the expected ports after reboot; `babaii` delay probe becomes healthy.
- [ ] `auto` group includes `babaii` as alive; manual `curl -x socks5h://192.168.70.1:1080` via `babaii` alone returns 200.
