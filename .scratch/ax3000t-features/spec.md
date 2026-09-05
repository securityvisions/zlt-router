# ax3000t-features — spec

Expand the Xiaomi AX3000T (`192.168.1.1`, OpenWrt 25.12.5) from a clean unbricked baseline into a high-performance, resilient, gaming-friendly, and secure primary household router, while strictly maintaining zero-brick and zero-auto-reboot guarantees.

## Context

The AX3000T (MediaTek Filogic 820 MT7981B, 256MB RAM, 33.5MB overlay free) was successfully unbricked and rebuilt on clean OpenWrt 25.12.5. It currently runs:
- LAN: `192.168.1.1/24` with DHCP server (`br-lan` = `lan2`, `lan3`, `lan4`, Wi-Fi).
- WAN: Auto-sensing via `wan-detector` procd service (Layer 2 ARP probe binds X28 to static `192.168.70.2` on whichever port it is plugged into).
- Wi-Fi 6: `XI-5G` (HE80 ch36) & `XI-2G` (HE20 ch1), WPA2-PSK (`xirouter123`).
- Proxy: `sing-box` 1.13.18 with transparent redirect on port 12345 (VLESS+Reality & Hysteria2 to VPS `85.121.124.158`).
- Domestic split-routing: `geosite-ir` and `geoip-ir` route DIRECT.
- QoS: CAKE SQM on WAN (50M/15M).
- Safety: `/etc/init.d/bootcount` resets U-Boot failure counters to 0 on every boot.
- Hardware backups: All 6 stock partitions saved in `C:\Users\Public\axtftp\backup\`.

This feature suite layers performance, gaming, privacy, and remote access capabilities onto this clean base without risking memory exhaustion or boot loops.

## Hard Safety Rules (Bind Every Ticket)

1. **Zero Automated Reboots:** No package, service, or watchdog may execute `reboot` automatically upon network loss or proxy drop.
2. **Memory Budget Cap:** Total background RAM usage across all added features must not exceed 25 MB (leaving >75 MB headroom on the 239 MB total).
3. **Storage Budget Cap:** Total overlay footprint across all added features must not exceed 15 MB (leaving >18 MB headroom on the 33.5 MB free).
4. **Independent Operability:** The AX3000T must operate seamlessly whether the X28 is powered on or off.
5. **No Secrets in Repo:** Passwords, tokens, and private keys remain in router config or `.secrets/` files.

## Tickets

1. `01-tcp-bbr.md` — Kernel TCP BBR congestion control + fq pacing
2. `02-mediatek-wed.md` — MediaTek WED (Wireless Ethernet Dispatch) hardware Wi-Fi offload
3. `03-wpa3-mixed.md` — WPA3-Personal transition mode (`sae-mixed`) on XI-5G & XI-2G
4. `04-upnp-nat-pmp.md` — UPnP / NAT-PMP daemon (`miniupnpd-nftables`) for Open Gaming NAT
5. `05-adblock-fast.md` — Network-wide lightweight ad & tracker blocking (`adblock-fast`)
6. `06-guest-iot-wifi.md` — Isolated Guest & Smart Home Wi-Fi network (`XI-Guest`)
7. `07-wake-on-lan.md` — Remote Wake-on-LAN web control (`etherwake` + `luci-app-wol`)
8. `08-cloudflare-tunnel.md` — Cloudflare Zero Trust remote mobile access (`cloudflared`, wontfix)
9. `09-luci-nlbwmon-ui.md` — Visual per-device bandwidth monitor (`luci-app-nlbwmon`)
10. `10-luci-sqm-ui.md` — Visual CAKE SQM QoS web control (`luci-app-sqm`)
11. `11-luci-ttyd-terminal.md` — In-browser web terminal (`ttyd` + `luci-app-ttyd`)
12. `12-usteer-band-steering.md` — Wi-Fi 6 AP roaming & band steering (`usteer`)
13. `13-iperf3-speedtest.md` — Local Wi-Fi 6 speed benchmark server (`iperf3`)
14. `14-umdns-discovery.md` — Multicast DNS service discovery reflector (`umdns`)
15. `15-luci-theme-material.md` — Modern mobile-responsive LuCI theme (`luci-theme-material`)

## Dependency Graph

```
01 (TCP BBR) ──────────────┐
                           ├──► 08 (Cloudflare Tunnel, wontfix)
02 (MTK WED) ──────────────┤
                           │
03 (WPA3-Mixed) ──► 06 (Guest Wi-Fi)

09 (nlbwmon UI)
10 (sqm UI)
11 (ttyd terminal)
12 (usteer band steering)
13 (iperf3 benchmark)
14 (umdns reflector)
15 (Material theme)

Independent:
04 (UPnP NAT-PMP)
05 (Adblock-Fast)
07 (Wake-on-LAN)
```

## Rollback & Baseline Preservation

Baseline snapshot `C:\Users\Public\axtftp\backup\ax3000t-resilience-final.tar.gz` is preserved. Any ticket can be individually backed out via `apk del <package>` or UCI reversion.
