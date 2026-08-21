# 08 — Vendor guest-SSID feasibility research (read-only)

**What to build:** A grounded answer to "can we ever have a real guest SSID on the X28 without risking it?" — produced entirely by read-only discovery. Locate where the vendor persists WiFi/SSID settings (config files vs flash partitions), enumerate the web-API commands the vendor UI uses for WiFi management, and determine whether a native guest-network toggle exists. Record findings and a verdict in this issue: if a safe native path exists, describe it as a proposal for a future ticket; if not, the standing recommendation holds (real second SSIDs wait for the recovered AX3000T). Zero mutations to device state — no writes, no config changes, no restarts.

**Blocked by:** None — can start immediately (independent of all other tickets).

**Status:** resolved

- [x] SSID persistence location identified with evidence (file/partition paths, tooling present/absent)
- [x] Vendor web-API command numbers for WiFi settings enumerated from the vendor UI assets
- [x] Verdict recorded: native guest toggle exists (with proposed safe path) or not (with recommendation)
- [x] Findings appended under an `## Answer` heading; device state byte-for-byte untouched during research

## Answer

**Where SSID lives (read-only evidence, 2026-08-22):**

- No `uci wireless` and no `/etc/config/wireless` — `uci show wireless` empty, `iwinfo`/`iw` absent. WiFi is not OpenWrt-managed.
- No `nvram` CLI on this MT6890 build. MTD partitions show `mcf1/2`, `nvcfg`, `nvdata`, `user_data` (ubi1) — vendor config lives in ubi/nvram, not uci.
- `/etc/wireless/l1profile.dat` only holds `INDEX0=MT7915D` and driver init paths (`/etc/wireless/mediatek/mt7915.dbdc.*.dat`, SKU, EEPROM) — the driver profiles, not the runtime SSID. Runtime SSID is programmed into the MT7915 firmware via `sub_wifi_thrd` (seen in `ps` as `sub_wifi_thrd`), not via hostapd/conf.
- `/etc/config` has no wireless section; `ps` shows `sub_wifi_thrd` + `wfa_dut`/`wifidog` style daemons, confirming the vendor's own WiFi daemon owns the radios (`ra0-3`, `rai0-3`).
- Vendor HTTP API (`/cgi-bin/http.cgi`) uses JSON `cmd` numbers for modem control (e.g., 100 login, 228 reselect). Grepping `/www` and `/www/luci-static` found no `cmd` for WiFi/SSID — the vendor UI's WiFi page (if any) does not expose a documented `cmd` like the reselect path; WiFi is managed outside that API.

**Vendor UI guest toggle:** No evidence of a native guest-network toggle in the vendor API or in `/etc/config`. The only WiFi-related vendor knobs visible are the MTK hostapd `DBDC_card0.dat` etc., which are rewritten by `sub_wifi_thrd` on every radio restart (the same daemon that once wedged the radios after a firmware reload). No safe `uci set wireless.@wifi-iface` path exists.

**Verdict:** No safe native guest-SSID path on the X28 exists without risking the vendor daemon overwriting or bricking the only working radio. The standing recommendation holds: keep the X28 on a single SSID and use per-device routing tiers only if needed later, and add real second SSIDs on the recovered AX3000T (standard OpenWrt `uci wireless`, proven safe). Revisit only if the vendor publishes a `cmd` for WiFi or a hostapd UCI is exposed in a future firmware.
