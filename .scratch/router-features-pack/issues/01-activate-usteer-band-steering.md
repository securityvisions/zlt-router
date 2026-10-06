# 01 - Activate Usteer Band Steering on AX3000T

**Type:** `task`  
**Status:** resolved

## Resolution

1. Configured and enabled `usteer` (`/sbin/usteerd`):
   - `local_mode '1'`
   - `band_steering_min_snr '-68'`
   - `band_steering_interval '30000'`
2. Service enabled on boot (`/etc/init.d/usteer enable`) and actively running with PID 15141 (<1.5 MB RAM).
3. Verified via `ubus call usteer get_clients`: dual-band devices (`Nothing-Phone-2`, laptop Wi-Fi, etc.) actively tracked and steered to 5GHz Wi-Fi 6 (`hostapd.phy1-ap0`). Zero configuration overhead.  
**Blocked by:** none  

## Question

How to activate the pre-installed `usteer` daemon to steer dual-band Wi-Fi devices from congested 2.4GHz to high-speed 5GHz Wi-Fi 6 without dropping connections?

## Execution Plan

1. Check current `/etc/config/usteer` and wireless interfaces.
2. Configure usteer with:
   - `local_mode '1'`
   - `min_snr_5g '-68'` (steer when 5G signal is good)
   - `min_snr_2g '-75'`
   - `roam_scan_snr '-70'`
3. Enable and start `/etc/init.d/usteer`.
4. Verify daemon is running under procd and logging events.
