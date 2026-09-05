# 13 — Local Wi-Fi 6 Speed Benchmark Server (iperf3)

**What to build:** Install `iperf3` on the AX3000T and configure a lightweight procd background daemon (`/etc/init.d/iperf3`) listening on port 5201. Enables benchmarking true physical Wi-Fi 6 throughput between client devices and the router (700–900+ Mbps) without consuming cellular data or hitting external servers.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

## Implementation Details

- Package: `iperf3` (8.2 KiB).
- Procd init script: `/etc/init.d/iperf3`:
  ```sh
  #!/bin/sh /etc/rc.common
  USE_PROCD=1
  START=95
  STOP=10

  start_service() {
      procd_open_instance
      procd_set_param command /usr/bin/iperf3 -s -p 5201
      procd_set_param respawn 3600 5 0
      procd_close_instance
  }
  ```
- Firewall: ensure port 5201 is accessible from LAN.

## Verification Criteria

- [ ] `iperf3` daemon active under procd (`ps | grep iperf3`).
- [ ] Running `iperf3 -c 192.168.1.1` from PC or phone measures local Wi-Fi 6 speeds.
- [ ] Idle footprint check: <10 KB flash, 0 MB background CPU/RAM.
