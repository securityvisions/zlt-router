# 02 — MediaTek WED (Wireless Ethernet Dispatch) Hardware Wi-Fi Offload

**What to build:** Enable `mt7915e.wed_enable=Y` in the kernel module options so Wi-Fi 6 packet forwarding is handled directly in silicon by the MediaTek MT7981 Packet Processing Engine (PPE). Reduces router CPU load from heavy multi-device Wi-Fi 6 streaming and gaming down to near 0%.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

## Implementation Details

- Kernel module parameter: `wed_enable` on driver `mt7915e`.
- Verification of current state: `cat /sys/module/mt7915e/parameters/wed_enable` (currently `N`).
- Persistent configuration: `/etc/modules.d/mt7915e`:
  ```ini
  options mt7915e wed_enable=Y
  ```
- Trigger reload: `wifi reload` or quick module reload.

## Verification Criteria

- [ ] `cat /sys/module/mt7915e/parameters/wed_enable` returns `Y`.
- [ ] Wi-Fi interfaces `XI-5G` and `XI-2G` remain up and broadcasting normally.
- [ ] Concurrent 4K streaming / heavy download over Wi-Fi 6 keeps router CPU usage under 5% on `top`.
- [ ] Footprint check: 0 KB flash install (built into kernel module), 0 MB RAM.
