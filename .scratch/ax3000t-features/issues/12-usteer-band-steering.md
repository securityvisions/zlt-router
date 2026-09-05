# 12 — Wi-Fi 6 AP Roaming & Band Steering (usteer)

**What to build:** Install `usteer` on the AX3000T. Configure 802.11k/v assisted roaming and band steering between `XI-5G` and `XI-2G`. Automatically steers dual-band clients to 5GHz when signal is strong (> -68 dBm), and smoothly transitions them to 2.4GHz when signal degrades (< -76 dBm).

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

## Implementation Details

- Package: `usteer` (73 KiB).
- Configuration: `/etc/config/usteer`:
  - Network: `lan`
  - Steer clients between `phy0` (2.4G) and `phy1` (5G).
  - RSSI threshold for 5G steering: `-68`.
  - RSSI kick threshold: `-76`.
- Enable and start via procd: `/etc/init.d/usteer enable && /etc/init.d/usteer start`.

## Verification Criteria

- [ ] `usteer` installed and running under procd (`ps | grep usteer`).
- [ ] `ubus call usteer get_clients` reports connected client band metrics.
- [ ] Connecting client near router automatically associates on 5GHz (`XI-5G`).
- [ ] Footprint check: <80 KB flash, ~1.5 MB RAM.
