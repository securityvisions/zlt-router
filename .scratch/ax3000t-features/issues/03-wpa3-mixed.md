# 03 — WPA3-Personal Transition Mode (sae-mixed)

**What to build:** Update UCI wireless configuration for `default_radio0` (2.4G) and `default_radio1` (5G) to use `encryption='sae-mixed'` with `ieee80211w='1'` (Protected Management Frames, optional). Enables WPA3 security for modern smartphones, laptops, and consoles while maintaining transparent backwards compatibility for legacy WPA2 devices.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

## Implementation Details

- Target interfaces: `wireless.default_radio0` (XI-2G) and `wireless.default_radio1` (XI-5G).
- Required UCI parameters:
  ```sh
  uci set wireless.default_radio0.encryption='sae-mixed'
  uci set wireless.default_radio0.ieee80211w='1'
  uci set wireless.default_radio1.encryption='sae-mixed'
  uci set wireless.default_radio1.ieee80211w='1'
  uci commit wireless
  wifi reload
  ```
- Package check: `wpad-basic-mbedtls` on OpenWrt 25.12.5 includes SAE (WPA3-Personal) support out-of-the-box. If missing, `wpad-openssl` or `wpad-mbedtls` can be provided.

## Verification Criteria

- [ ] `iw dev` confirms both `XI-2G` and `XI-5G` are up.
- [ ] Laptop/phone Wi-Fi analyzer confirms beacon includes WPA3 (SAE) + WPA2 (PSK).
- [ ] Modern smartphone / laptop associates cleanly using WPA3.
- [ ] Legacy device associates cleanly using WPA2 with the same key (`xirouter123`).
- [ ] Zero connection drops during handshake; PMF is set to optional (`1`).
