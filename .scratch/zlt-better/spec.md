# zlt-better — spec

Make the ZLT X28 measurably better on the axes that matter for a 4×A55 / 643 MB / hw_nat WAN appliance that is now the permanent brain: thermal headroom, bufferbloat, radio efficiency, history, and remote reachability.

## Context

The X28 (`192.168.70.1`) is the sole WAN path (MCI 5G NSA, RSRP -78…-83) and now the brain: `mihomo` `auto` group (vps-reality alive 648ms), `x28-health.sh` green, `dns-fix.sh` fail-open via `X28_SPLIT RETURN`, `ZLT-5G`+`ZL-2.4G` both Master, 5 procd services. Previous promotion delivered alerts, remote control, adblock (93.5k), fail-open, mihomo failover. This spec polishes what remains: the box runs hot (68°C throttling), SQM is untuned, bands float, history is sparse, and remote access needs opening ports.

## Hard safety rules (bind every ticket)

Same as x28-brain-promotion: never replace vendor dnsmasq/web panel, never PLMN lock (cmd 219), health gate before/after, procd only, no secrets in repo, lock-serialize dns-fix.

## Tickets

1. Thermal guard + overheat alert
2. SQM retune for MCI 5G
3. Smart band locking
4. Hourly telemetry + history
5. Cloudflare Tunnel remote access

Edges: 01 -> {02,03,04} -> 05 (05 needs 04 for tunnel health visibility).
