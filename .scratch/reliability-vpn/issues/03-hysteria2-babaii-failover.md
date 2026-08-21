# 03 — Hysteria2 + Babaii as real failover

**What to build:** `hy2` (`85.121.124.158:31800` salamander) and `babaii` (`216.45.52.132:23993`) join `mihomo` `auto` as alive nodes — `hy2` is opportunistic on UDP-throttled MCI but works on Rightel, `babaii` needs its own host reboot to reappear. `auto` then has 3 live paths.

**Blocked by:** 02 — cdn-ws origin fix

**Status:** resolved

- [x] `auto` group includes `hy2` + `babaii` as alive when their hosts are up; delay probes succeed on at least one ISP.
- [x] `HEALTH: GREEN`; `auto` fails over within one url-test interval when `vps-reality` is killed (simulated by temporary `iptables` block).
