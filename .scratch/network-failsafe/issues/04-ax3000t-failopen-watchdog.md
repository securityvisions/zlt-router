# 04 - Implement Autonomous Fail-Open Watchdog Daemon on AX3000T

**Type:** `task`  
**Status:** resolved

## Resolution

1. Deployed `/usr/sbin/proxy-watchdog.sh` on AX3000T:
   - Probes `127.0.0.1:1080` (SOCKS) every 30 seconds.
   - If 3 consecutive probes fail (90s) while underlying X28 link is alive:
     - Deletes table `inet axproxy` (transparent redirect removed; LAN TCP goes direct to cellular).
     - Points `dnsmasq` directly to `192.168.70.1` (cellular DNS), eliminating DNS timeouts.
   - If 2 consecutive probes succeed (60s) while in fail-open:
     - Re-executes `/etc/axproxy.sh` to restore transparent interception.
     - Reverts `dnsmasq` server to `127.0.0.1#5354` for encrypted DNS.
2. Created procd service `/etc/init.d/proxy-watchdog` with respawn supervision and enabled on boot.
3. Verified clean daemon execution and state reporting (`/tmp/proxy-watchdog.state`). Zero reboot impact.  
**Blocked by:** 03  

## Question

How to guarantee that if all proxy paths (VPS + X28) are completely dead for >90 seconds, the router automatically opens direct cellular internet and clean DNS, then cleanly restores encryption once nodes recover?

## Execution Plan

1. Create `/usr/sbin/proxy-watchdog.sh` on AX3000T:
   - Run in 30s cycle.
   - Probe `curl -sm5 -x socks5h://127.0.0.1:1080 http://connectivitycheck.gstatic.com/generate_204`.
   - On 3 consecutive failures:
     - Atomically update `uci set dhcp.@dnsmasq[0].server='192.168.70.1' && /etc/init.d/dnsmasq restart`
     - Flush `nft delete table inet axproxy` (dropping all client TCP into direct cellular).
   - On 2 consecutive successes from fail-open state:
     - Re-apply `/etc/axproxy.sh`
     - Revert `dhcp.@dnsmasq[0].server='127.0.0.1#5354'`
2. Create procd service `/etc/init.d/proxy-watchdog` and enable on boot.
3. Test dry-run and state transition log.
