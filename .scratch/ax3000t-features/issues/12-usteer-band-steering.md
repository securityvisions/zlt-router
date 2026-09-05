# 12 — Wi-Fi 6 AP Roaming & Band Steering (usteer)

**What to build:** Install `usteer` on the AX3000T. Configure 802.11k/v assisted roaming and band steering between `XI-5G` and `XI-2G`. Automatically steers dual-band clients to 5GHz when signal is strong (> -68 dBm), and smoothly transitions them to 2.4GHz when signal degrades (< -76 dBm).

**Blocked by:** None — can start immediately.

**Status:** resolved

## Implementation Details

- Installed `usteer` (2025.10) from official feed.
- Configured `/etc/config/usteer` with `local_mode=1`, `band_steering_interval=30000`, `band_steering_min_snr=-68`.
- Running under procd (`/sbin/usteerd`).
- Verified via `ubus call usteer get_clients` and `ubus call usteer local_info`: tracks real-time signal across `XI-5G`, `XI-2G`, and `XI-Guest`.
- Automatically steers dual-band clients to 5GHz when signal >= -68 dBm, with smooth 2.4GHz fallback.

## Verification Criteria

- [x] `usteer` installed and running under procd (`ps | grep usteer`).
- [x] `ubus call usteer get_clients` reports connected client band metrics.
- [x] Active client associations tracked live with RRM neighbor reports (`rrm_nr`).
- [x] Footprint check: <80 KB flash, ~1.4 MB RAM.
