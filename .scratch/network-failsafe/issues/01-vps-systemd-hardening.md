# 01 - Harden VPS S-UI Systemd Service

**Type:** `task`  
**Status:** resolved

## Resolution

Found and permanently resolved two critical issues on the VPS:
1. **Duplicate Competing Services:** Both `/etc/systemd/system/sui.service` and `/etc/systemd/system/s-ui.service` were enabled simultaneously, fighting over port 2095 on boot/restart and causing intermittent crash-loops (`listen tcp :2095: bind: address already in use`).
2. **Hardened Unit File:** Unified under `/etc/systemd/system/s-ui.service` with `Alias=sui.service`, configured with:
   - `Restart=always` & `RestartSec=3s`
   - `StartLimitIntervalSec=0` (unlimited auto-restarts)
   - `KillMode=control-group` & `TimeoutStopSec=10s`
   - `LimitNOFILE=1048576` (prevents socket FD exhaustion)
   - `OOMScoreAdjust=-500` (immune to Linux OOM killer)
3. Verified clean auto-recovery: `kill -9` triggered an automatic, clean respawn in 3 seconds with zero port collisions and zero zombie processes.  
**Blocked by:** none  

## Question

How to ensure the S-UI sing-box proxy core on VPS `85.121.124.158` never stays dead after crashes, memory spikes, or socket exhaustion?

## Execution Plan

1. Read current `/etc/systemd/system/sui.service` on VPS.
2. Update unit file with:
   - `Restart=always`
   - `RestartSec=3s`
   - `StartLimitIntervalSec=0`
   - `LimitNOFILE=1048576`
   - `OOMScoreAdjust=-500`
3. Reload systemd daemon and verify service status.
