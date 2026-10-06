# 03 - Align ProbeService & dns-fix Contract on X28

Status: resolved
Assignee: agent
Type: task

## Answer

1. **Root Cause Confirmed:**
   - `/data/proxy/probe-service.sh` defaulted `PROBE_SOCKS` to `127.0.0.1:1070` (an obsolete PassWall port). On X28, Mihomo runs on `192.168.70.1:1080`. Connection attempts to 1070 failed immediately with connection refused.
   - `probe-service.sh` used `check) probe_check "${2:-link}" && echo alive || echo dead ;;`. Because `echo dead` always exits with 0, the script returned exit code 0 even when dead, breaking callers relying on exit status (like `dns-fix.sh`).
2. **Resolution Applied:**
   - Updated `PROBE_SOCKS` to default to active Mihomo port `192.168.70.1:1080`.
   - Updated the `check` and `data` CLI handlers in `probe-service.sh` to explicitly `exit 0` on alive and `exit 1` on dead.
   - Synced and verified unit tests (`router/tests/test_x28link.sh` passing 14/14, `router/tests/test_x28watch.sh` passing 9/9).
   - Deployed to `/data/proxy/probe-service.sh` on X28 and verified:
     - Normal healthy check: outputs `alive`, exit code 0.
     - Simulated failure (`PROBE_SOCKS=127.0.0.1:9999`): outputs `dead`, exit code 1.
Blocked by: none

## Question

How should `/data/proxy/probe-service.sh` and `/data/proxy/dns-fix.sh` be aligned to correctly probe the active Mihomo SOCKS port (:1080) and return authentic exit codes so fail-open behaves deterministically?

### Findings & Context

1. `/data/proxy/probe-service.sh` defaults `PASSWALL_PROBE_SOCKS` to port 1070 (obsolete PassWall daemon). No service listens on 1070.
2. In `probe-service.sh` line 67: `check) probe_check "${2:-link}" && echo alive || echo dead ;;`. Even when probe fails, `echo dead` exits with return code 0.
3. In `dns-fix.sh` line 50: `sh /data/proxy/probe-service.sh check passwall >/dev/null 2>&1 && return 0 || return 1`. Because the exit code is always 0, `tunnel_ok` incorrectly assumes the tunnel is always up via probe-service.
