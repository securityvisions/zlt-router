# reliability-vpn — spec

Make the X28's VPN and the box itself reliably self-healing: the VPS core restarts itself when hung, every node in the mihomo auto group is actually healthy, and the config never gets lost to lan_mgr or a bad deploy.

## Context

X28 `192.168.70.1` is green with mihomo `auto` = `vps-reality` alive (766ms), `HEALTH: GREEN`, but `cdn-ws` and `hy2` time out (origin port/CFI and MCI UDP throttling), `babaii` is dead until its host reboots, and the 01:00 sing-box hang needed a manual panel restartSb. The fail-open in `dns-fix.sh` saved the house, but the tunnel stayed down 75 min.

## Tickets

1. VPS auto-heal watchdog (panel restartSb when tunnel dead 10 min)
2. cdn-ws origin fix (Cloudflare edge → origin :8443)
3. Hysteria2 + Babaii as real failover (all 4 in auto)
4. Backup + liveness hardening (nightly tar + health probe)
