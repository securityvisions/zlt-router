# 01 - Build netpull: status, pull, never push

Status: resolved
Type: task

## Question

What exact file manifest does `netpull` cover, where does the diff manifest live, and what do `status` / `pull` output — so that repo↔device divergence (the Sept 16 incident class) is always visible and one command backs everything up?

### Constraints (from ADR-0007)

- Device is canonical; `netpull` NEVER pushes to device-owned configs.
- Must cover at minimum: X28 `/data/proxy/` set (mihomo/config.yaml, dns-fix.sh, probe-service.sh, tproxy-fixed-enable.sh, watchdog scripts) and AX3000T `/etc/sing-box/config.json`, `/etc/axproxy.nft`, `/usr/sbin/proxy-watchdog.sh` (this one has NO repo copy yet — first pull closes the gap).
- Repo-authored tools (probe-service.sh per ADR-0007 §5) still deploy repo→device; `status` must distinguish "device owns this" vs "repo owns this" direction so the alarm doesn't fire on legitimate deploys.

## Answer

`netpull` (router/netpull.sh, deployed nowhere — runs from the laptop) ships with:
- **Manifest (in-script, 11 entries):** `owner|name|device_path|repo_path|host` covering X28 /data/proxy (mihomo-config, dns-fix, operator-watchdog, x28-vps-heal, probe-service, tproxy-fixed-enable, linkstate) and AX3000T (proxy-watchdog, axproxy-nft, axproxy-sh, sing-box-config). Extend by appending lines.
- **Commands:** `status` (batched md5 per router, one ssh each → match/DIVERGED/NO-DEVICE/NO-REPO table), `pull <name|all>` (device → repo with tmp+mv atomicity), `manifest`.
- **NEVER pushes** (ADR-0007). Env seams: NETPULL_AX, NETPULL_X28, NETPULL_ROOT — tests run device-free with stub "ssh" scripts emitting fixture hashes.
- Tests: router/tests/test_netpull.sh — 10/10. Includes an ADR-guard assertion: if netpull ever emits a device-write in a recorded ssh command, the test fails.
- Gotchas encoded in tests: remote is `xargs md5sum`+args (AX busybox lacks xargs → paths-as-args), ssh stdin must be </dev/null inside read loops, eval must not re-quote $cmd.
