# 01 - Eliminate dnsmasq DNS Poison Caching on X28

Status: resolved
Assignee: agent
Type: task

## Answer

1. **Root Cause Confirmed:** In `dns-fix.sh`, transitions back from ISP mode to tunnel mode only sent `kill -HUP $p`. In `dnsmasq`, `SIGHUP` reloads the config file but preserves the in-memory DNS cache. Because ISP mode points to cellular DNS `10.201.112.252` which returns poisoned IP `10.10.34.35` for all filtered domains, this poisoned answer remained cached in RAM indefinitely after returning to tunnel mode.
2. **Resolution Applied:**
   - Added `clear-on-reload` to `/tmp/dnsmasq.conf` whenever tunnel mode is attached.
   - Updated `/data/proxy/dns-fix.sh` (and `router/x28/dns-fix.sh`) so that when the upstream mode changes (`$before != $after`), `dnsmasq` is terminated and relaunched (`killall dnsmasq; sleep 1; dnsmasq -C "$CONF" ...`), unconditionally wiping all cached poisoned records.
   - Preserved `/tmp/dnsmasq.leases` on disk so DHCP clients never drop leases or connectivity.
   - Verified that subsequent runs without configuration changes are strictly idempotent (`mode=tunnel (no change)`).
   - Validated that `nslookup youtube.com 192.168.70.1` now resolves directly to genuine, unpoisoned Google edge IPs (`192.178.183.x`) instead of `10.10.34.35`.
Blocked by: none

## Question

How should `dnsmasq` on X28 be configured and reloaded so that ISP DNS poisoning (`10.10.34.35`) is never cached or served to `ZL-5G` clients when switching between ISP and tunnel modes?

### Findings & Context

When `dns-fix.sh` switches to ISP mode, or when vendor `lan_mgr` overwrites `/tmp/dnsmasq.conf`, queries go to MCI cellular DNS (`10.201.112.252`) which returns poisoned IP `10.10.34.35` for censored domains. Dnsmasq caches this. Later when `dns-fix.sh` restores tunnel mode (`server=127.0.0.1#5353`), it issues `kill -HUP $p`. In `dnsmasq`, `SIGHUP` does not clear the cache, causing ZL-5G clients to continue receiving poisoned records and timing out indefinitely.
