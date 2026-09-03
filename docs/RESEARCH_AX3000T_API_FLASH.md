# Research: Xiaomi AX3000T — flashing OpenWrt via the stock API without SSH/UART

Date: 2026-09-02. Scope: RD03 (CN, stock 1.0.47, fresh TFTP recovery), authenticated RCE via `xqsystem/start_binding`, no SSH, no UART. Verified device facts from today's session are treated as ground truth; all external claims cited inline. Style per `docs/RESEARCH_AX3000T_FAILSAFE.md`.

## TL;DR

1. **xmir-patcher never uses the stock firmware-update API.** It transfers files to `/tmp` over SCP/FTP/Telnet-echo and flashes with `mtd write` / `ubiformat` commands over SSH/Telnet [1][2]. Its whole flow gates on getting SSH or Telnet first (`gateway.run_cmd` has no web-API executor) [1].
2. **The stock update endpoint would NOT accept the OpenWrt factory.ubi**: `xqsystem/upload_rom` → `cutImage` (Xiaomi HDR header) → `verifyImage` (signature) → error **1554**; the actual flash is `xqsystem/flash_rom` → `forkExec("flash.sh <file> [1]")` [7][8]. No signature bypass exists for RD03 (xqimage.py's fake-sign payloads cover R3G…RA72 only) [6].
3. **Official install path is RCE→SSH→wiki commands** [3]; on our box only the *dropbear channel-gate* is missing: stock `/etc/init.d/dropbear` refuses to start while it contains `= "release"` [1][3]. A **quote-free** `sed -i s/release/debug/g /etc/init.d/dropbear` dispatches fine under our sanitizer.
4. **The sanitizer is per-parameter** `XQSecureUtil.filterChars` = ``[`;|$&]`` (newer builds add `\n`), but params named `name`/`ssid`/`password`… are **skipped** [1]. That's why `xqsystem/set_mac_filter`'s `name` param accepts `;`-chained commands [5].
5. **Slot safety**: running slot comes from `/proc/cmdline` (`firmware=0`/`1`); mtd8 `ubi`=slot0, mtd9 `ubi1`=slot1; always `ubiformat` the *opposite* one and flip the five nvram flags [3][4].
6. Best plan below = 6 quote-free dispatches to open SSH, then the wiki procedure verbatim.

## Q1. How xmir-patcher installs firmware; which slot; does stock updater auto-set flags?

- `install_fw.py` parses the image locally (stock HDR1, uImage, FIT or UBI), then `gw.upload()` to `/tmp/fw_img.bin|kernel.bin|rootfs.bin` and flashes via `gw.run_cmd('mtd -e "{part}" write "{bin}" "{part}"')`; **no stock upload endpoint is ever called** [2].
- For MT7981 filogic devices it selects `install_method = 400  # mtk filogic`, `install_parts = ['ubi','ubi1']`, requires the image to be UBI-wrapped (`kernel.into_ubi`) and, for OpenWrt, **initramfs only** (`die('OpenWRT: Supported only InitRamFS images (400)')`) [2]. Our 10 MB `initramfs-factory.ubi` is exactly that class of image.
- Slot choice: `self.install_fw_num = 1 - dev.rootfs.num` — **it writes the INACTIVE slot**, then `activate_boot.uboot_boot_change()` flips nvram flags and verifies `flag_boot_rootfs == install_fw_num` [2][4].
- Stock's own updater (`upload_rom`+`flash_rom`) does set boot state — the flash is delegated to `/sbin/flash.sh` via `forkExec("flash.sh <file> [1]")` after `sysLock()`; with A/B devices flash.sh targets the inactive slot and the bootloader's rollback logic governs boot (inferred from [3][4][8]; flash.sh itself not dumped).
- `upload()` paths: SSH-SCP, FTP, or Telnet `echo -n <b64-chunk>` + `base64 -d | gzip -d` — all PC→router initiated [1]. xmir-patcher never needs router→PC connectivity for flashing; only the get_icon exploit (connect7) requires the router to fetch from the PC [5].

## Q2. Would stock's update API accept the OpenWrt factory image?

- Pipeline (decompiled 1.0.155 controller, same generation as 1.0.47): multipart field **`image`** → `cutImage(path)` fail→**1554** → `verifyImage(path)` fail→**1554** → `checkRomVersion` → `downgrade` flag [7][8].
- The Xiaomi image header is `HDR1|sign|crc32|type|model|files[8]` + per-section `BE BA / addr / size / mtd / name` blocks + a signature section — xqimage.py re-implements it and shows the sign payload differs per model, hardcoded for R3G/R3P/R3600/RA69/RA70/RA72 only; **no RD03/RD23 entry** [6].
- OpenWrt `*-factory.ubi` starts with `UBI#` magic, has no HDR header and no signature → `cutImage`/`verifyImage` reject it. OpenWrt's factory.ubi for AX3000T is *not* built "so stock sysupgrade accepts it" — the wiki flashes it with `ubiformat` after SSH [3].
- No published case of flashing OpenWrt via stock web/API upload on AX3000T-class MT7981 Xiaomi units was found (wiki + thread 180490 all go RCE→SSH, UART, or TFTP-recovery of *stock* images) [3][9].
- The TFTP bootloader recovery also validates the signature (that is what the fake-sign trick was for — RD03 not covered) [6].

## Q3. RD03 partition layout, A/B semantics, boot flags

- Stock mtd layout (wiki backup commands): **mtd1 BL2, mtd2 Nvram, mtd3 Bdata, mtd4 Factory, mtd5 FIP, mtd8 `ubi`, mtd9 `ubi1`, mtd12 KF** [3].
- **mtd8=slot0, mtd9=slot1**: wiki flash step "If firmware=0 → `ubiformat /dev/mtd9` + flags for slot 1; If firmware=1 → `ubiformat /dev/mtd8` + flags for slot 0" [3].
- Running slot: `cat /proc/cmdline` contains `firmware=0` or `firmware=1` [3]. Cross-check `nvram get flag_boot_rootfs`.
- Boot algorithm (stock uboot pseudocode, quoted in activate_boot.py): `flag_last_success` picks the slot; `flag_ota_reboot==1` toggles it; a failed boot sets `flag_try_sysN_failed=1`, and on the next boot a set try-flag flips to the other slot; `flag_boot_rootfs` is written by uboot before bootm; kernel0 magic check `0x27051956` [4].
- xmir-patcher's slot activation exactly: `nvram set flag_ota_reboot=0; flag_boot_success=1; flag_last_success=<n>; flag_try_sys1_failed=0; flag_try_sys2_failed=0; flag_boot_rootfs=<n>; nvram commit` [4]. Wiki adds `boot_wait=on; uart_en=1` [3]. Safe fallback: leave the current slot untouched and flags consistent → worst case uboot reverts to it.

## Q4. Error codes 1541/1523, the sanitizer, and workarounds

- **Sanitizer**: Xiaomi's `XQSecureUtil.filterChars` is applied per-request-parameter. xmir-patcher's detector (gateway.py) fingerprints three variants: filterChars ``[`;|$&]`` returning nil (hackCheck 2), the same *plus* `\n` (hackCheck 3), or returning '' (hackCheck 1) [1]. Our observed profile — `\n` passes, `` ` ; | $ & `` fail — matches hackCheck 2.
- **Skip-list**: params named `name, password, ssid, pwd, username, apn, …` bypass the filter entirely (`hackCheck_skipKeys_v2`) [1]. Hence `xqsystem/set_mac_filter` injection puts the command into `name` and chains with `;`: `name='xxx ; uci set diag.config.usb_read_thr=<ms> ; uci commit diag ; '<cmd>` [5].
- **1541**: in the bind flow of xqsystem.lua the code sets `1541` when the matool/cloud-bind result is not `code==0/data.bind==1` [10] — empirically the same bare `{"code":1541}` surfaces when the sanitizer mangles the `key` payload and the internal bind command fails. Treat 1541 as "request rejected/mangled".
- **1523**: generic *invalid parameter* — set in isStrNil/length checks [11] and e.g. `xqnetwork/set_wan_lan_port` when `XQLanWanUtil.setWanLanPort(mode)` returns nil [12].
- **Workarounds** (all primary-sourced):
  - **Newline chaining**: `%0A` runs sequential commands in one dispatch (connect6 replaces `;`→`\n` for exactly this reason) [5].
  - **`if …\n then …\n fi`**: no banned chars → conditionals with exit-status observation.
  - **Quote-free sed**: `sed -i s/release/debug/g /etc/init.d/dropbear` replaces the channel gate without quotes/redirects [3][5].
  - **`passwd -d root`** instead of `echo … > file | passwd` (no redirect) [3].
  - **Alternate injectors**: `misystem/arn_switch` (params `open/mode/level`; *the* documented exploit for 1.0.47 CN) [3][5]; `xqsystem/set_mac_filter` via skip-listed `name` [5]; `xqdatacenter/request` payload `{"api":7,…,"vendor":";<cmd>;#",…}` [5][13].
  - **Bulk transfer without router→PC**: `misystem/c_upload` accepts an uploaded tar.gz and restores it (R3G POC chain: c_upload → `xqnetdetect/netspeed` execs injected `speedtest_urls.xml`; the same firmware exposes unauthenticated file read `GET /api-third-party/download/extdisks../tmp/<f>`) [14]. Endpoint exists in the 1.0.4x controller set [12]; whether 1.0.47 restores arbitrary archives must be tested.
  - **Verification side-channel**: injected `uci set diag.config.iperf_test_thr=<n>; uci commit diag` → read back via authenticated `xqnetwork/diag_get_paras` (connect6/7 use this to confirm execution without SSH) [5].

## Q5. netmode, set_router_normal, WAN/LAN port mapping

- `misystem/set_router_normal` exists in the controller entry table (mapped to a "router info/normal" handler) [12]; semantics of netmode values are not covered by any dumped source — treat published enumerations as hearsay. Known from device: after the offline wizard netmode=4; `set_router_normal` returned workmode:0.
- Port mapping is a stock *feature* on this generation: `xqnetwork/get_wan_lan_port` → `getWanLanMode()` and `xqnetwork/set_wan_lan_port` with a single param **`mode`** → `XQLanWanUtil.setWanLanPort(mode)` (nil→1523) [12]; XQFeatures exposes `apps.wanLan`, `apps.lanPort`, `apps.ports_custom` [1][15]. Wiki notes stock "dynamically assigns LAN/WAN" [3].
- "WAN link:0 forever on a healthy unit after TFTP recovery" — no forum hit found (search rate-limited during research); recommended first tries over the RCE: `misystem/set_router_normal`, then `xqnetwork/set_wan_lan_port` with the value returned by `get_wan_lan_port` flipped, re-reading `xqnetwork/wan_info` between attempts. If OpenWrt is the goal anyway, this problem disappears post-flash (OpenWrt's own `wan`/`lan2-4` DSA config is static) [3].

## Q6. Other paths without SSH/UART

- **xmir-patcher end-to-end**: `run.sh` → option 2 tries its exploit set (connect6 order: start_binding → arn_switch → set_mac_filter → datacenter7; connect7 get_icon+upload_log needs router→PC HTTPS) to install dropbear, then install_fw does the rest — it *does* support router-unreachable-to-PC (SCP/Telnet uploads are PC→router), but only after its exploit opens SSH/Telnet [1][5].
- **TFTP-recovery with OpenWrt**: rejected (signature) [6]; TFTP stays a stock-restore / downgrade tool [3].
- **facinstall**: runs *on OpenWrt* to install factory images — not usable pre-flash [16].

## Recommended plan (cheapest safe order)

1. **Establish a verified single-command executor.** Baseline `GET …/api/xqnetwork/diag_get_paras`; dispatch `uid=1234&key=1234'%0Auci%20set%20diag.config.iperf_test_thr%3D82000011%0Auci%20commit%20diag%0A'`; re-read `diag_get_paras`. If unchanged, send `uci set` and `uci commit` as separate dispatches. This converts fire-and-forget into verifiable execution [5].
2. **Open SSH — all quote-free, sanitizer-safe** (dispatch each; port 22 is the binary success signal):
   `nvram set ssh_en=1` → `nvram commit` → `sed -i s/release/debug/g /etc/init.d/dropbear` → `/etc/init.d/dropbear enable` → `/etc/init.d/dropbear restart` → `passwd -d root` [1][3][5]. (The previously missed dropbear channel-gate sed is why port 22 never opened.)
3. If 22 still closed: replay step 2 through **arn_switch** (`open=0&mode=1&level=%0A<cmd>%0A`) [5] and **set_mac_filter** (`name` param, `;`-chained, single line) [5]; keep start_binding as fallback.
4. With SSH: `scp` the 10 MB `initramfs-factory.ubi` to `/tmp`; `cat /proc/cmdline` → slot N; **`ubiformat /dev/mtd9 -y -f /tmp/*.ubi`** (if N=0) else `/dev/mtd8`; set the wiki flag block (Q3) for slot 1-N; `reboot` [3]. No-flash-kept-slot = safe rollback.
5. After initramfs boots (middle LAN port, `ssh root@192.168.1.1`): `sysupgrade -n /tmp/*squashfs-sysupgrade.bin` [3].
6. Post-flash, from OpenWrt, backup what matters: `dd if=/dev/mtd4` (Factory/cal), `mtd3` (Bdata), `mtd2` (Nvram) — these were never touched by this path.
7. Only if SSH proves impossible: plan B = `misystem/c_upload` tar.gz to /tmp (Q4) + injection-driven, diag-verified `ubiformat` via newline `if/then/fi` — every step confirmed before the next; never flash blind.

## Caveats / conflicts

- The 1.0.155 dump is not 1.0.47: controller logic drifts (arn_switch is `tonumber`-hardened there); codes/handler names may differ on 1.0.47 — quoted behavior marked with dump-generation caveat [7][12].
- Whether stock `flash.sh` picks the inactive slot is inferred (A/B + rollback pseudocode + xmir-patcher convention), not read from flash.sh source [2][3][4].
- Router→PC connectivity "failure" was only ever observed through fire-and-forget dispatches; re-test with the diag-verified executor (step 1) and `tcpdump` before declaring it dead — plan B depends on it.

## Sources

1. xmir-patcher `gateway.py` (`run_cmd/upload/detect_hackCheck/hackCheck_skipKeys_v2`) — https://github.com/openwrt-xiaomi/xmir-patcher/blob/main/gateway.py
2. xmir-patcher `install_fw.py` (method 400, inactive-slot, `mtd -e … write`) — https://github.com/openwrt-xiaomi/xmir-patcher/blob/main/install_fw.py
3. OpenWrt wiki: Xiaomi AX3000T (RCE table, flash instructions, mtd map) — https://openwrt.org/toh/xiaomi/ax3000t (via Wayback 2026-08-13)
4. xmir-patcher `activate_boot.py` (`uboot_boot_change` + stock uboot pseudocode) — https://github.com/openwrt-xiaomi/xmir-patcher/blob/main/activate_boot.py
5. xmir-patcher `connect6.py`, `connect7.py`, `connect5.py`, `install_ssh.py` (4 injectors, get_icon/upload_log, dropbear `release` gate) — https://github.com/openwrt-xiaomi/xmir-patcher/blob/main/connect6.py
6. xmir-patcher `xqimage.py` (HDR1/XQImgFile format, `build_sign` model table) — https://github.com/openwrt-xiaomi/xmir-patcher/blob/main/xqimage.py
7. Unpacked Xiaomi LuCI `xqsystem.lua` 1.0.155 (`uploadRom`: cutImage/verifyImage/1554) — https://github.com/dmamontov/miwifi-luci-api/blob/main/miwifi_ra70_firmware_982c0_1.0.155/xqsystem.unluac.lua
8. Same repo, `flash_rom` handler (`verifyImage` + `forkExec("flash.sh …")`) — ibid. lines 3652-3790
9. Forum thread "OpenWrt support for Xiaomi AX3000T" (methods, get_icon note #3766) — https://forum.openwrt.org/t/openwrt-support-for-xiaomi-ax3000t/180490
10. Same dump as [7], bind flow setting 1541 — ibid. line 3328
11. Unpacked `misystem.lua` 1.0.95 (1523 on isStrNil/len checks) — https://github.com/dmamontov/miwifi-luci-api/blob/main/miwifi_ra72_all_11c68_1.0.95/misystem.unluac.lua
12. Unpacked `xqnetwork.lua` RB06 1.0.48 (`set_wan_lan_port` `mode` param, `misystem` entry `set_router_normal`, `c_upload` entry) — https://github.com/dmamontov/miwifi-luci-api/blob/main/miwifi_rb06_firmware_847e9_1.0.48/xqnetwork.unluac.lua
13. Publication for the `xqdatacenter/request` injection — https://xz.aliyun.com/news/91619 (as cited in connect6.py; site unreachable during research)
14. R3G POC (c_upload tar.gz + netspeed exec + `extdisks..` file read) — https://github.com/UltramanGaia/Xiaomi_Mi_WiFi_R3G_Vulnerability_POC
15. xmir-patcher `unlock_features.py` (XQFeatures feature tree incl. `apmode`, `wanLan`, `lanPort`) — https://github.com/openwrt-xiaomi/xmir-patcher/blob/main/unlock_features.py
16. facinstall (factory-image installer for OpenWrt ≥21.02) — https://github.com/openwrt-xiaomi/facinstall
