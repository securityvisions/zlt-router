# 03 - Tune MiniUPnP for Gaming Open NAT (IGDv2)

**Type:** `task`  
**Status:** resolved

## Resolution

1. Upgraded MiniUPnP configuration in `/etc/config/upnpd`:
   - `igdv1 '0'` (enabled full modern UPnP IGDv2 and NAT-PMP standard).
   - Removed artificial 1Mbps rate-reporting clamps, setting gigabit line-rate negotiation.
2. Verified `/var/etc/miniupnpd.conf`:
   - Bound directly to active WAN `lan4` and LAN bridge `br-lan`.
   - `force_igd_desc_v1=no`, `enable_natpmp=yes`.
   - Native nftables integration (`upnp_table_name=fw4`) for zero-overhead gaming port forwards (Open NAT). Daemon running with PID 16306 (<1.4MB RAM).  
**Blocked by:** none  

## Question

How to update MiniUPnP settings on the AX3000T to achieve Open NAT type on PlayStation 5, Xbox, and PC gaming without artificial 1Mbps rate limits?

## Execution Plan

1. Inspect `/etc/config/upnpd`.
2. Configure:
   - `enable_upnp '1'`
   - `enable_natpmp '1'`
   - `igdv1 '0'` (upgrade to modern UPnP IGDv2 standard)
   - Remove legacy 1Mbps download/upload rate reporting constraints so modern high-bandwidth clients negotiate full line rate.
3. Restart `/etc/init.d/miniupnpd` and verify listening status and ruleset in nftables.
