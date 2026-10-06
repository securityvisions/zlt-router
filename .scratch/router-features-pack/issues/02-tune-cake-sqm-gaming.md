# 02 - Tune CAKE SQM with diffserv4 & ack-filter for Gaming

**Type:** `task`  
**Status:** resolved

## Resolution

1. Configured CAKE SQM on the active WAN interface (`lan4`):
   - Ingress: 95 Mbps (`95000 kbps`), Egress: 25 Mbps (`25000 kbps` calibrated for cellular 5G uplink).
   - Egress options: `diffserv4 ack-filter`
   - Ingress options: `diffserv4`
2. Verified via `tc -s qdisc show dev lan4`:
   - Active qdisc shows `diffserv4 triple-isolate nat nowash ack-filter`.
   - 4-tin QoS separation (`Bulk`, `Best Effort`, `Video`, `Voice`) actively separates gaming/voice packets from high-bandwidth downloads.
   - `ack-filter` active to prevent upstream TCP ACK packet congestion on cellular uplink. Zero dropped packets under test.  
**Blocked by:** none  

## Question

How to optimize CAKE SQM queueing on the AX3000T's active WAN port (`lan4`) to eliminate bufferbloat and guarantee minimum latency for gaming/Discord packets under heavy household downloading?

## Execution Plan

1. Check current `/etc/config/sqm` on AX3000T.
2. Ensure active WAN device (`lan4`) has:
   - `qdisc 'cake'`
   - `script 'layer_cake.qos'` or `cake.qos`
   - `diffserv 'diffserv4'` (prioritizes gaming, voice, and DNS into highest tin)
   - `ack_filter '1'` (filters redundant upstream TCP ACKs, preventing cellular upstream saturation)
3. Apply via `/etc/init.d/sqm restart` and verify queue stats with `tc -s qdisc show dev lan4`.
