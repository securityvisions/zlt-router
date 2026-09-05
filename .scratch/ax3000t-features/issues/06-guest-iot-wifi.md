# 06 — Isolated Guest & Smart Home (IoT) Wi-Fi Network

**What to build:** Create an isolated virtual Wi-Fi interface (`XI-Guest`) on 2.4GHz with its own bridge interface (`br-guest` / `192.168.3.1/24`), DHCP pool, and firewall zone. Isolates guests and smart home IoT appliances (smart plugs, vacuum robots, bulbs) so they have internet access, but cannot reach private computers, file shares, or router admin.

**Blocked by:** 03 — WPA3-Mixed (builds on wireless base).

**Status:** ready-for-agent

## Implementation Details

- Network configuration (`/etc/config/network`):
  ```uci
  config device
      option name 'br-guest'
      option type 'bridge'

  config interface 'guest'
      option device 'br-guest'
      option proto 'static'
      option ipaddr '192.168.3.1'
      option netmask '255.255.255.0'
  ```
- DHCP configuration (`/etc/config/dhcp`):
  ```uci
  config dhcp 'guest'
      option interface 'guest'
      option start '100'
      option limit '150'
      option leasetime '12h'
  ```
- Firewall configuration (`/etc/config/firewall`):
  ```uci
  config zone
      option name 'guest'
      option network 'guest'
      option input 'REJECT'
      option output 'ACCEPT'
      option forward 'REJECT'

  config rule
      option name 'Allow-Guest-DNS'
      option src 'guest'
      option dest_port '53'
      option proto 'tcp udp'
      option target 'ACCEPT'

  config rule
      option name 'Allow-Guest-DHCP'
      option src 'guest'
      option src_port '68'
      option dest_port '67'
      option proto 'udp'
      option target 'ACCEPT'

  config forwarding
      option src 'guest'
      option dest 'wan'
  ```
- Wireless configuration (`/etc/config/wireless`):
  ```uci
  config wifi-iface 'guest_radio0'
      option device 'radio0'
      option network 'guest'
      option mode 'ap'
      option ssid 'XI-Guest'
      option encryption 'psk2'
      option key 'xiguest123'
      option isolate '1'
  ```

## Verification Criteria

- [ ] `XI-Guest` SSID broadcasts on 2.4GHz.
- [ ] Connecting client receives IP in `192.168.3.x` range.
- [ ] Client can browse the internet normally (domestic & international).
- [ ] Client CANNOT ping `192.168.1.1` or access LuCI/SSH web admin.
- [ ] Client CANNOT communicate with devices on `192.168.1.x` (private LAN).
- [ ] Client isolation prevents guests on `XI-Guest` from probing each other.
