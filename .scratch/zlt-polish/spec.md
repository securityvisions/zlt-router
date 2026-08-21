# zlt-polish — spec

Polish the ZLT X28 after the brain promotion and mihomo failover: fix the origin-mismatch that keeps cdn-ws timing out, keep hy2 as opportunistic UDP failover, revive babaii, and lock the DHCP DNS fix that unblocked YouTube. All remain after `zlt-better` (thermal/SQM/band/telemetry/tunnel stubs) and the Samantel credential now on device.

## Context

`mihomo` `auto` group is `vps-reality` alive, `HEALTH: GREEN`, `dns-fix.sh` fail-open with the `X28_SPLIT RETURN` bypass, `114.114.114.114` stripped from `dnsmasq`. Samantel balance now live (`118.3 GB` via `***REDACTED***`).

## Tickets

1. cdn-ws origin port (188.114.98.0 pin vs :8443)
2. hy2 UDP keep-alive (opportunistic)
3. babaii server revive
4. DHCP DNS single-source lock (already live, needs doc + test)
