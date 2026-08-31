# Research: Xiaomi AX3000T — Failsafe entry, LEDs, ports, and unbrick paths

Date: 2026-08-31. Scope: Xiaomi AX3000T (RD03/RD23, MT7981B) running OpenWrt 25.12.x, stock Xiaomi bootloader or OpenWrt U-Boot. All claims cited inline; note-taking convention per `docs/`.

## TL;DR

1. **Failsafe**: power on, then **tap reset rapidly and repeatedly from the moment any orange blink appears**. Window is **4 s** (OpenWrt ≥ 24.10) signalled by orange blinking at ~5/s; success = **~10/s orange blink that persists** and the device then listens on **192.168.1.1 (SSH only)**.
2. **Only the port labeled LAN2 answers in failsafe** (2nd RJ45 from the left; chassis order left→right: **WAN, LAN2, LAN3, LAN4**).
3. **Best fallback**: stock bootloader **DHCP+TFTP recovery** — hold reset from before power-on, release when orange flashes; PC runs DHCP+TFTP (dnsmasq) at 192.168.31.100; router fetches a file named after its DHCP IP in hex (`C0A81F02.img`). With OpenWrt U-Boot (ubootmod layout) instead: TFTP-serve `...ubootmod-initramfs-recovery.itb` at **192.168.1.254**, loaded automatically.
4. **UART**: 115200 8N1 3.3V.

## Q1. Exact failsafe entry procedure

- The button-press window is `fs_failsafe_wait_timeout`, built from `CONFIG_TARGET_PREINIT_TIMEOUT`, **default 4 s since commit `5004f37` (PR #11852, merged Oct 2024)**; it was 2 s before. Wiki: "four seconds in 24.10 and later OpenWrt versions, but only two seconds on 23.05 and earlier." [1][2][3][4]
- `failsafe_wait()` polls for a button press (any button; press writes `/tmp/failsafe_button`) and for the `f` key on serial during that window (`30_failsafe_wait` source). [5]
- The window opens when preinit starts, i.e. a few seconds after power-on on an MT7981. Practical timing is by LED (below). You can also `tcpdump -Ani <iface> port 4919 and udp` for the window broadcast containing "Please press button now to enter failsafe". [1][5]
- Official wiki: "Power on the device, wait for a flashing LED and press a button. This can be the WPS, Reset, or other button." AX3000T-specific forum advice: "be sure to **spam the reset button immediately after applying power**... press the button rapidly/repeatedly until you see an LED rapidly flashing." So: tap repeatedly (a single well-timed tap suffices, but spamming is the reliable technique); do not just hold once. [1][6]
- **On success**: LED switches to ~10 blinks/s and **keeps blinking indefinitely** — failsafe has no timeout (`run_failsafe_hook` loops until `/tmp/sysupgrade`), so the device stays in failsafe until you reboot it; it does not continue booting. [5][7][8]
- Failsafe exists only on squashfs/overlay builds (all official AX3000T images are squashfs). [1]

## Q2. LED meanings during boot (OpenWrt)

- DT aliases in `mt7981b-xiaomi-mi-router-common.dtsi`: `led-boot = &led_status_yellow; led-failsafe = &led_status_yellow; led-running = &led_status_blue; led-upgrade = &led_status_yellow;` — i.e. **orange (DT "yellow") = boot/failsafe/upgrade; blue = running**. [7]
- `diag.sh` + `leds.sh` timers: `preinit` → `led_timer 100 100` (≈5 blinks/s, the failsafe window); `failsafe` → `led_timer 50 50` (≈10 blinks/s, persists); `preinit_regular` → `led_timer 200 200` (≈2.5/s until boot completes); `done` → running LED (blue) solid. Wiki device page: "Yellow: Blinks during boot; Blue: Solid after boot; White: Not in use" (white = both LEDs on). [8][9][10]
- A healthy boot therefore shows **blinking** orange, not static. A "static orange for minutes → off → reboot" loop is what boot-failing AX3000T units show ("The LED stays orange for about 10 seconds, then turns off for a couple of seconds, then turns orange again, repeating" — thread 212425; "Slow flashing orange light, eventually stable orange" — thread 180490 #110). [11][12]
- With reset **held from power-on**, the **stock bootloader** shows: "Steady orange 8s → Rapid blink 4s → Steady orange 20+ seconds → repeat forever", and "At the moment of blinking, this is the bootloader's request to download the file" (TFTP retry). This matches the "blinks briefly → static → blinks again" loop you observed while pressing reset. [12]

## Q3. Which port answers in failsafe

- AX3000T network config: `ucidef_set_interfaces_lan_wan "lan2 lan3 lan4" wan` (`target/linux/mediatek/filogic/.../02_network`). [13]
- Failsafe/preinit brings up **only the first port of the `lan` device list**: `10_indicate_preinit`: "# only use the first one / ifname=${ports%% *}" (identical in openwrt-25.12 branch). So **failsafe = 192.168.1.1 on `lan2` only**; WAN never answers. [5][14]
- Wiki (generic): "Try the LAN1 port first. DSA devices frequently enable LAN1 only" — on the AX3000T there is no lan1; the first LAN port is **lan2**. [1]
- Physical chassis labels (wiki photo `ax3000t_ports.png`): left→right **WAN, LAN2, LAN3, LAN4**; install docs: "plug the ethernet cable into one of the middle ports" for LAN. DT port labels confirm `wan`/`lan2`/`lan3`/`lan4` (no lan1). [15][16][7]
- **Gotcha**: laptop in the WAN port (leftmost) gets no ARP reply from 192.168.1.1 in failsafe — try LAN2 (second from left) first, then LAN3/LAN4. Stock-bootloader TFTP recovery, in contrast, DHCP-broadcasts on the **LAN ports** (middle ports). [17]

## Q4. Window length and difficulty reports

- The window is the same 4 s as other devices (not per-device shorter), but MT7981 boots fast, so it starts early (~2-4 s after power-on) and ends quickly; preinit boot logs show `- preinit -` ~2 s after kernel start on comparable hardware. [1][2][18]
- Forum evidence of difficulty on this device: thread 249660 — "For failsafe... spam the reset button immediately after applying power... until you see an LED rapidly flashing"; thread 215777 — user reached fast-blink but SSH failed (needs static IP 192.168.1.x; failsafe has **no DHCP and no HTTP, SSH only**); thread 212425 — users did enter failsafe "three times" after package-induced boot loops, with the LED phase mapping "off / slow blink / fast blink / steady on". [6][19][11]

## Q5. Fallbacks if failsafe cannot be triggered

### (a) Stock bootloader DHCP+TFTP recovery (no UART needed) — recommended
Official wiki procedure (AX3000T page, "TFTP instructions for the stock bootloader"): "AX3000T can be recovered from a soft-brick with TFTP. The router boots and asks for an IP address on the LAN ports via DHCP... then connects to the TFTP server... and tries to download a file named with the IP address given by the DHCP server converted to hexadecimal (for example, 192.168.31.2 → file `C0A81F02.img`)." Steps: PC on a **middle/LAN** port, static **192.168.31.100/24**; on Linux: `dnsmasq --no-daemon --listen-address=192.168.31.100 --bind-interfaces --dhcp-range=192.168.31.2,192.168.31.254 --enable-tftp --tftp-root=/tmp/tftp`; serve a **stock** firmware renamed `C0A81F02.img` (watch the TFTP log — if the router asks for a different name, rename accordingly and retry). "Power off... Press and hold the reset button, then power on while still holding... Keep holding until the router's LED starts flashing orange. Then release... the device will start loading the firmware... Wait until the blue led starts flashing!... then power cycle." Disconnect any ISP/WAN cable first (it can interfere). Windows: `tftpd64` with DHCP pool giving 192.168.31.2, or Xiaomi's MIWIFIRepairTool (automated DHCP+TFTP). [17][20][12]

### (b) UART/serial recovery
- Pins on the board (wiki photo), parameters: **115200, 8N1, 3.3V**. With stock bootloader (install sets `nvram set uart_en=1; nvram set boot_wait=on`), U-Boot offers a menu: "Connect to router via UART → Select *Load Image* → Set start address 0x48000000, then set TFTP parameters to load the initramfs-kernel.bin → Start the loaded kernel, then perform sysupgrade" (press Esc/Ctrl+C to interrupt; prompt `MT7981>`; `setenv ipaddr 192.168.1.1; setenv serverip 192.168.1.254`). [16][21][22]
- If you are on the **OpenWrt U-Boot (ubootmod) layout**: "u-boot will also look for a file called `openwrt-mediatek-filogic-xiaomi_mi-router-ax3000t-ubootmod-initramfs-recovery.itb` in a tftp server at IP address 192.168.1.254... it'll be automatically loaded and run, so system can be recovered without using a UART connection." [21]
- Bootloader itself bricked: `mtk_uartboot` loads a bootloader over UART (forum post 180490/860; full UART flash method in 180490/420). [22][23][24]

### (c) Other paths
- If OpenWrt boots at all but is unreachable: long-press reset (≥5 s) = factory reset (Q6), or failsafe → `mount_root` then fix `/overlay/etc/config/network` (or `firstboot`). [1]
- Note: with the stock bootloader, a configuration-reset quirk "after 6 reboots, caused by the stock Xiaomi bootloader logic" existed pre-24.10 (fixed by PR #17580) — repeated failed boots may wipe config on very old builds. [16][25]

## Q6. Reset button during normal running

`/etc/rc.button/reset` (base-files, openwrt-25.12 identical): on `released`, `SEEN < 1` s → plain **reboot**; `SEEN >= 5` s and overlay present → `factoryreset -y && reboot` (hard factory reset); while still held past ~5 s the `timeout` event runs `set_state failsafe` (orange ~10/s blink) to signal reset is armed. Wiki: "Press and hold the reset button for 10 seconds" then release. So a long-press **does** factory-reset on this device without SSH — but only if the system boots far enough to run procd, which a boot loop prevents. Buttons in DT: `reset` (KEY_RESTART), `mesh` (BTN_9). [14][1][7]

## Conflicts / caveats

- The device page's "Switch Ports (for VLANs)" table is garbled/stale ("Numbers 2-4 are Ports 1-3 as labeled on the unit..."); the DT labels (`wan, lan2, lan3, lan4`) and the port photo are authoritative. [15][16][7]
- Stock TFTP recovery file name: wiki says the router requests the hex-IP name; users report the requested name can differ per unit — trust the TFTP server log. [17][12]

## Sources

1. Failsafe mode, factory reset, and recovery mode — https://openwrt.org/docs/guide-user/troubleshooting/failsafe_and_factory_reset (via Wayback 2026-01-01)
2. PR #11852 "Increase failsafe trigger wait time from 2 to 4 sec" — https://github.com/openwrt/openwrt/pull/11852
3. `package/base-files/image-config.in` (`TARGET_PREINIT_TIMEOUT` default 4) — https://github.com/openwrt/openwrt/blob/main/package/base-files/image-config.in
4. Commit b4e33a1 (00_preinit.conf is generated by base-files Makefile) — https://github.com/openwrt/openwrt/commit/b4e33a1c08f7e0b980b14687ef601bd30634464a
5. `package/base-files/files/lib/preinit/30_failsafe_wait` — https://github.com/openwrt/openwrt/blob/main/package/base-files/files/lib/preinit/30_failsafe_wait
6. Forum: "Xiaomi AX3000T (OpenWrt) – Changed Default IP..." — https://forum.openwrt.org/t/xiaomi-ax3000t-openwrt-changed-default-ip-now-no-dhcp-no-ip-assignment/249660
7. `target/linux/mediatek/dts/mt7981b-xiaomi-mi-router-common.dtsi` — https://github.com/openwrt/openwrt/blob/main/target/linux/mediatek/dts/mt7981b-xiaomi-mi-router-common.dtsi
8. `package/base-files/files/etc/diag.sh` — https://github.com/openwrt/openwrt/blob/main/package/base-files/files/etc/diag.sh
9. `package/base-files/files/lib/functions/leds.sh` — https://github.com/openwrt/openwrt/blob/main/package/base-files/files/lib/functions/leds.sh
10. OpenWrt Wiki: Xiaomi AX3000T (LEDs, buttons) — https://openwrt.org/toh/xiaomi/ax3000t (via Wayback 2026-06-24)
11. Forum: "Xiaomi AX3000T Bricked (no rapid blink)" — https://forum.openwrt.org/t/xiaomi-ax3000t-bricked-no-rapid-blink/212425
12. Forum: "OpenWrt support for Xiaomi AX3000T" #110 — https://forum.openwrt.org/t/openwrt-support-for-xiaomi-ax3000t/180490/110
13. `target/linux/mediatek/filogic/base-files/etc/board.d/02_network` — https://github.com/openwrt/openwrt/blob/main/target/linux/mediatek/filogic/base-files/etc/board.d/02_network
14. `10_indicate_preinit` (openwrt-25.12 branch) — https://github.com/openwrt/openwrt/blob/openwrt-25.12/package/base-files/files/lib/preinit/10_indicate_preinit
15. AX3000T WAN/LAN ports photo — https://openwrt.org/_media/media/xiaomi/ax3000t_ports.png
16. OpenWrt Wiki: Xiaomi AX3000T (Debricking, TFTP, Serial, install) — https://openwrt.org/toh/xiaomi/ax3000t (via Wayback 2026-06-24)
17. Same page, section "TFTP instructions for the stock bootloader" — https://openwrt.org/toh/xiaomi/ax3000t#tftp_instructions_for_the_stock_bootloader
18. PR #10235 (preinit timing log) — https://github.com/openwrt/openwrt/pull/10235
19. Forum: "Xiaomi AX3000T got damaged lying down" — https://forum.openwrt.org/t/xiaomi-ax3000t-got-damaged-lying-down/215777
20. Xiaomi MiWiFi Repair Tool — http://bigota.miwifi.com/xiaoqiang/tools/MIWIFIRepairTool.x86.zip
21. Device page, "Debricking" (U-Boot auto-TFTP at 192.168.1.254) — https://openwrt.org/toh/xiaomi/ax3000t#debricking
22. Forum: AX3000T support thread #860 (mtk_uartboot) — https://forum.openwrt.org/t/openwrt-support-for-xiaomi-ax3000t/180490/860
23. Forum: AX3000T support thread #420 (UART flash method) — https://forum.openwrt.org/t/openwrt-support-for-xiaomi-ax3000t/180490/420
24. mtk_uartboot — https://github.com/981213/mtk_uartboot
25. PR #17580 (stock bootloader 6-reboot config reset fix) — https://github.com/openwrt/openwrt/pull/17580
