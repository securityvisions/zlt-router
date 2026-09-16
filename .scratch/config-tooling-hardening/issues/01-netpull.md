# 01 - Build netpull: status, pull, never push

Status: open
Type: task

## Question

What exact file manifest does `netpull` cover, where does the diff manifest live, and what do `status` / `pull` output — so that repo↔device divergence (the Sept 16 incident class) is always visible and one command backs everything up?

### Constraints (from ADR-0007)

- Device is canonical; `netpull` NEVER pushes to device-owned configs.
- Must cover at minimum: X28 `/data/proxy/` set (mihomo/config.yaml, dns-fix.sh, probe-service.sh, tproxy-fixed-enable.sh, watchdog scripts) and AX3000T `/etc/sing-box/config.json`, `/etc/axproxy.nft`, `/usr/sbin/proxy-watchdog.sh` (this one has NO repo copy yet — first pull closes the gap).
- Repo-authored tools (probe-service.sh per ADR-0007 §5) still deploy repo→device; `status` must distinguish "device owns this" vs "repo owns this" direction so the alarm doesn't fire on legitimate deploys.
