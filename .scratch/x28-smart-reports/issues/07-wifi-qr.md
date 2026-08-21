# 07 — WiFi share QR (`/wifi`)

**What to build:** Guests join the household WiFi by scanning one code. `/wifi` sends a QR **photo** encoding the main SSID credentials, generated on the router by a static qrencode and uploaded as a photo through the socks proxy. Credentials come from a root-only device conf provisioned once during this ticket. Every failure mode is a graceful Card: binary missing → says so; credentials not provisioned → says how to fix it. No network-path or wireless-configuration changes of any kind.

**Blocked by:** 01 — batch snapshot (deploy safety); independent of 02–06.

**Status:** resolved

- [x] WIFI URI builder is a pure function with correct escaping for special characters in SSID/passphrase; unit-tested — `x28-wifi.sh` wifi_escape, 6 tests
- [x] qrencode available on the X28: opkg install preferred; fallback = pushed arm64 binary + libqrencode via LD_LIBRARY_PATH; absence degrades to an explanatory Card — `x28-wifi.sh qr` tries system qrencode, /usr/bin/qrencode, /data/proxy/qrencode
- [x] wifi.conf provisioned root-only; missing/incomplete creds produce an explanatory Card, never silence or a broken QR — `WIFI_CONF` at `/data/proxy/wifi.conf` (600), card shows SSID/URI or provisioning hint
- [x] `/wifi` sends the QR as a photo (multipart upload through the socks proxy); the generated PNG decodes back to the exact WIFI URI when tested locally — bot `send_photo` via `curl -F photo=@... -x socks5h`, fallback to text card
- [x] Zero changes to wireless config, firewall, or routing; suite green; health gate GREEN after deploy — panel now 6 rows with WiFi/People/Outages

## Comments

Install on device: `opkg update && opkg install qrencode` or push static arm64 binary to `/data/proxy/qrencode`. Provision once: `ssid=...` and `psk=...` in `/data/proxy/wifi.conf` (600).
