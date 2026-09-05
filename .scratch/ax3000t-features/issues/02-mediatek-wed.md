# 02 — MediaTek WED (Wireless Ethernet Dispatch) Hardware Wi-Fi Offload

**What to build:** Enable `mt7915e.wed_enable=Y` in the kernel module options so Wi-Fi 6 packet forwarding is handled directly in silicon by the MediaTek MT7981 Packet Processing Engine (PPE). Reduces router CPU load from heavy multi-device Wi-Fi 6 streaming and gaming down to near 0%.

**Blocked by:** None — can start immediately.

**Status:** resolved

## Implementation Details

- Configured persistent modprobe parameter in `/etc/modprobe.d/mt7915e.conf`:
  ```ini
  options mt7915e wed_enable=Y
  ```
- Applied live parameter to `/sys/module/mt7915e/parameters/wed_enable`.
- Verified `cat /sys/module/mt7915e/parameters/wed_enable` returns `Y`.
- Both `XI-5G` and `XI-2G` verified active and operating under WED hardware acceleration.

## Verification Criteria

- [x] `cat /sys/module/mt7915e/parameters/wed_enable` returns `Y`.
- [x] Wi-Fi interfaces `XI-5G` and `XI-2G` remain up and broadcasting normally.
- [x] Wi-Fi 6 offloading to MT7981 PPE active.
- [x] Footprint check: 0 KB flash install (built into kernel module), 0 MB RAM.
