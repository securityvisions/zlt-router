# 06 — Isolated Guest & Smart Home (IoT) Wi-Fi Network

**What to build:** Create an isolated virtual Wi-Fi interface (`XI-Guest`) on 2.4GHz with its own bridge interface (`br-guest` / `192.168.3.1/24`), DHCP pool, and firewall zone. Isolates guests and smart home IoT appliances (smart plugs, vacuum robots, bulbs) so they have internet access, but cannot reach private computers, file shares, or router admin.

**Blocked by:** 03 — WPA3-Mixed (builds on wireless base).

**Status:** resolved

## Implementation Details

- Created isolated bridge `br-guest` (`192.168.3.1/24`) and separate DHCP server pool (`192.168.3.100 - 192.168.3.200`).
- Configured dedicated `guest` firewall zone:
  - Default input: REJECT, forward: REJECT.
  - Forwarding to `wan` allowed (internet connectivity).
  - Forwarding to `lan` strictly blocked (private devices protected).
  - DNS (port 53) and DHCP (port 67) allowed to router only.
- Created `XI-Guest` SSID on 2.4GHz with WPA2 (`xiguest123`) and `isolate='1'`.
- Transparent proxy and ad-blocking integrated seamlessly for `br-guest`.

## Verification Criteria

- [x] `XI-Guest` SSID broadcasts on 2.4GHz.
- [x] Client connected to guest network receives `192.168.3.x` address.
- [x] Client can browse internet normally.
- [x] Client cannot access LuCI admin (`192.168.1.1` or `192.168.3.1`).
- [x] Client cannot communicate with private devices on `192.168.1.x`.
- [x] Client isolation active between guests.
