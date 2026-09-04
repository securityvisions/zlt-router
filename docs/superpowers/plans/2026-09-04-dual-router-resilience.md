# Dual-Router Resilience & Auto-Port Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the home network into an immune, auto-port, dual-VPN appliance where AX3000T runs its own independent sing-box TUN proxy on any physical port, X28 acts as cellular edge and backup VPN, and the system self-heals across power cuts and cable movements without auto-reboot loops.

**Architecture:** AX3000T runs a pure Linux TUN inbound on `kmod-tun` with `auto_route: true` (stack: system) connecting directly to the VPS via VLESS+Reality / Hy2 with domestic Iran split routing. A lightweight event-driven procd service on AX3000T (`wan-detector`) continuously senses which port is physically connected to the X28 via fast Layer 2 ARP probes (`arping`), dynamically designating it as static WAN (`192.168.70.2`) and bridging the other 3 ports into `br-lan`. X28 treats AX3000T traffic as passthrough while continuing to run its own independent Mihomo VPN for `ZL-5G`.

**Tech Stack:** OpenWrt 25.12.5 (Linux 6.12, apk), MediaTek MT7981B DSA switch (`wan`, `lan2`, `lan3`, `lan4`), `sing-box` 1.13.18 (`kmod-tun`), `iputils-arping`, UCI network/firewall/wireless.

**Spec:** `docs/superpowers/specs/2026-09-04-dual-router-resilience-design.md`

## Global Constraints

- Never add automatic reboot logic to AX3000T — zero auto-reboots under any failure condition.
- WAN configuration on AX3000T must remain static IP (`192.168.70.2/24`, gw `192.168.70.1`) — zero DHCP wait/backoff races.
- The 4 physical ports on AX3000T must be port-agnostic: connecting X28 into any port must make it WAN and the other 3 LAN.
- Both routers must support independent VPN connections: `XI-5G` via AX3000T sing-box, `ZL-5G` via X28 Mihomo.
- Keep all stock partition backups intact in `C:\Users\Public\axtftp\backup\`.

---

### Task 1: Kernel TUN Driver & Sing-Box Clean Inbound Configuration

**Files:**
- Modify: `router/sing-box-config.json`
- Target on Router: `/etc/sing-box/config.json`
- Driver package on Router: `kmod-tun`

**Interfaces:**
- Consumes: `/dev/net/tun` kernel character device provided by `kmod-tun`.
- Produces: `singtun` network interface with `auto_route: true`, `stack: system`.

- [ ] **Step 1: Install kmod-tun on AX3000T and verify /dev/net/tun**

Run on AX3000T via SSH:
```bash
apk add kmod-tun
ls -la /dev/net/tun
```
Expected output: `crw-rw-rw- 1 root root 10, 200 /dev/net/tun`

- [ ] **Step 2: Update sing-box-config.json to pure TUN mode**

Write clean TUN inbound configuration to `router/sing-box-config.json`:
- `type: "tun"`
- `interface_name: "singtun"`
- `address: ["172.19.0.1/30"]`
- `mtu: 1400`
- `auto_route: true`
- `strict_route: false`
- `stack: "system"`
- Ensure `auto_redirect` and `nfqueue` are completely omitted.

- [ ] **Step 3: Validate and push configuration to AX3000T**

Push config to `/etc/sing-box/config.json` and run:
```bash
sing-box check -c /etc/sing-box/config.json
```
Expected output: clean exit (code 0), no FATAL or validation errors.

- [ ] **Step 4: Start sing-box service and verify singtun interface**

Run on AX3000T:
```bash
/etc/init.d/sing-box restart
sleep 3
ip addr show singtun
```
Expected output: `singtun` is `UP`, inet `172.19.0.1/30`.

- [ ] **Step 5: Test DNS and Tunnel egress from AX3000T**

Run on AX3000T:
```bash
curl -s -m 10 -o /dev/null -w "%{http_code}\n" https://www.google.com
curl -s -m 10 -o /dev/null -w "%{http_code}\n" https://www.digikala.com
```
Expected output: Google `200` (via VPS tunnel), Digikala `200` (domestic direct).

- [ ] **Step 6: Commit**

```bash
git add router/sing-box-config.json
git commit -m "feat(ax3000t): enable pure TUN sing-box with kmod-tun system stack"
```

---

### Task 2: Auto-Sensing WAN Port Service (`wan-detector`)

**Files:**
- Create: `router/wan-detector.sh`
- Create: `router/wan-detector.init`
- Target on Router: `/usr/sbin/wan-detector`, `/etc/init.d/wan-detector`
- Package dependency on Router: `iputils-arping`

**Interfaces:**
- Consumes: Carrier state of `wan`, `lan2`, `lan3`, `lan4` via `/sys/class/net/<port>/carrier`.
- Produces: Dynamic assignment of detected uplink port to `network.wan` and remaining 3 ports to `network.@device[0].ports` (`br-lan`).

- [ ] **Step 1: Install iputils-arping on AX3000T**

Run on AX3000T:
```bash
apk add iputils-arping
which arping
```
Expected output: `/usr/bin/arping`

- [ ] **Step 2: Create wan-detector daemon script**

Write `router/wan-detector.sh`:
```sh
#!/bin/sh
# wan-detector.sh — Auto-sense which physical port connects to X28 (192.168.70.1)
# Ports: wan (port 1), lan2 (port 2), lan3 (port 3), lan4 (port 4)

X28_IP="192.168.70.1"
X28_MAC="98:a9:42:6b:67:b8"
CANDIDATES="wan lan2 lan3 lan4"
LOG_TAG="wan-detector"

detect_uplink() {
    for p in $CANDIDATES; do
        carrier=$(cat "/sys/class/net/$p/carrier" 2>/dev/null || echo 0)
        [ "$carrier" = "1" ] || continue
        
        # Fast ARP probe for X28 MAC
        reply=$(arping -I "$p" -c 1 -w 1 "$X28_IP" 2>/dev/null | grep -i "$X28_MAC" || true)
        if [ -n "$reply" ]; then
            echo "$p"
            return 0
        fi
    done
    return 1
}

apply_port_mapping() {
    new_wan="$1"
    curr_wan=$(uci get network.wan.device 2>/dev/null || echo "")
    [ "$new_wan" = "$curr_wan" ] && return 0

    logger -t "$LOG_TAG" "X28 detected on $new_wan (was: $curr_wan). Reconfiguring..."

    # Determine the other 3 ports for LAN
    lan_ports=""
    for p in $CANDIDATES; do
        [ "$p" = "$new_wan" ] && continue
        lan_ports="$lan_ports '$p'"
    done

    # Update UCI atomically
    uci set network.wan.device="$new_wan"
    uci -q delete network.@device[0].ports
    eval "uci add_list network.@device[0].ports=$lan_ports"
    uci commit network

    # Hot-reload WAN interface without dropping local LAN
    ifup wan
    logger -t "$LOG_TAG" "Uplink moved to $new_wan; LAN ports updated."
}

# Daemon loop
while :; do
    uplink=$(detect_uplink || true)
    if [ -n "$uplink" ]; then
        apply_port_mapping "$uplink"
        sleep 10
    else
        sleep 5
    fi
done
```

- [ ] **Step 3: Create procd init service**

Write `router/wan-detector.init`:
```sh
#!/bin/sh /etc/rc.common
START=99
STOP=10
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /usr/sbin/wan-detector
    procd_set_param respawn 3600 5 0
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}
```

- [ ] **Step 4: Deploy, enable, and verify wan-detector on AX3000T**

Push files to AX3000T, set executable permissions, and start service:
```bash
chmod +x /usr/sbin/wan-detector /etc/init.d/wan-detector
/etc/init.d/wan-detector enable
/etc/init.d/wan-detector start
ps | grep wan-detector
```
Expected output: procd instance of `/usr/sbin/wan-detector` running.

- [ ] **Step 5: Verify auto-detection behavior**

Verify current active WAN port detection in logread:
```bash
logread | grep wan-detector
```
Expected output: `wan-detector: X28 detected on lan4 (or current port) ...`

- [ ] **Step 6: Commit**

```bash
git add router/wan-detector.sh router/wan-detector.init
git commit -m "feat(ax3000t): add auto-sensing wan-detector procd daemon"
```

---

### Task 3: Power-Cut Resilience & Boot Hygiene

**Files:**
- Modify: `router/wan-detector.sh`
- Target on Router: `/etc/config/network`, `/etc/config/system`

**Interfaces:**
- Consumes: Kernel boot environment and UCI network settings.
- Produces: Static zero-backoff WAN addressing and permanent immunity to auto-reboot loops.

- [ ] **Step 1: Verify static WAN parameters in network config**

Confirm `/etc/config/network`:
```uci
network.wan.proto='static'
network.wan.ipaddr='192.168.70.2'
network.wan.netmask='255.255.255.0'
network.wan.gateway='192.168.70.1'
network.wan.dns='192.168.70.1'
```
Verify: no DHCP retry loops or timeouts on WAN boot.

- [ ] **Step 2: Audit all scripts on AX3000T for reboot calls**

Run audit on AX3000T:
```bash
grep -rn "reboot" /etc/rc.local /etc/init.d/ /etc/hotplug.d/ 2>/dev/null || true
```
Expected output: Zero automated watchdog reboot scripts present.

- [ ] **Step 3: Add S99bootcount reset guard to AX3000T**

To permanently prevent the stock U-Boot bootcounter climb that caused the original brick:
Create `/etc/init.d/bootcount-guard`:
```sh
#!/bin/sh /etc/rc.common
START=99

boot() {
    # Zero out U-Boot try failure counters on every clean boot
    nvram set flag_try_sys1_failed=0 2>/dev/null || true
    nvram set flag_try_sys2_failed=0 2>/dev/null || true
    nvram commit 2>/dev/null || true
}
```
Enable service:
```bash
chmod +x /etc/init.d/bootcount-guard
/etc/init.d/bootcount-guard enable
```

- [ ] **Step 4: Commit**

```bash
git add router/bootcount-guard.init
git commit -m "fix(ax3000t): add bootcount-guard to guarantee U-Boot partition stability"
```

---

### Task 4: X28 Passthrough Alignment

**Files:**
- Target on X28: `/data/proxy/tproxy-enable.sh`
- Repository: `router/x28/tproxy-enable.sh`

**Interfaces:**
- Consumes: Inbound traffic from AX3000T WAN (`192.168.70.2`).
- Produces: Direct passthrough on X28 without double-proxying or re-encryption.

- [ ] **Step 1: Verify X28 tproxy exclusion for 192.168.70.2**

Check running iptables on X28:
```bash
iptables -t nat -L X28_TPROXY -n -v | grep "192.168.70.2"
```
Ensure `192.168.70.2` has `RETURN` in `X28_TPROXY`, meaning packets from AX3000T (already encrypted and routed by sing-box on AX3000T) are passed directly to `ccmni1` without double-handling by Mihomo.

- [ ] **Step 2: Update router/x28/tproxy-enable.sh in git to match**

Verify repo copy `router/x28/tproxy-enable.sh` specifies `EXCLUDE="192.168.70.2"`.

- [ ] **Step 3: Verify X28 Mihomo remains active on ZL-5G**

On X28:
```bash
curl -s -m 5 -x socks5h://127.0.0.1:1080 https://www.gstatic.com/generate_204
```
Expected output: HTTP 204.

- [ ] **Step 4: Commit**

```bash
git add router/x28/tproxy-enable.sh
git commit -m "fix(x28): align tproxy bypass for AX3000T WAN (192.168.70.2)"
```

---

### Task 5: End-to-End Testing & Power-Race Simulation

**Files:**
- Test scripts: `router/tests/test_resilience_e2e.sh`

**Interfaces:**
- Comprehensive verification of Auto-WAN port detection, Dual-VPN independence, and boot race recovery.

- [ ] **Step 1: Test Auto-Port Switching**

Test physical cable plug test:
1. Current cable is in `lan4`. Confirm WAN is `lan4`.
2. Move cable to `wan` (port 1). Wait 15 seconds.
3. Check `uci get network.wan.device` on AX3000T. Expected: `wan`.
4. Ping `8.8.8.8` from AX3000T. Expected: 0% loss.
5. Move cable to `lan2` (port 2). Wait 15 seconds.
6. Check `uci get network.wan.device`. Expected: `lan2`.
7. Move back to preferred port.

- [ ] **Step 2: Test Dual-VPN Isolation**

1. Connect laptop to `XI-5G`:
   - Visit IP checking service / curl trace: exit IP is VPS (`85.121.124.158`).
   - Visit YouTube / Google / Telegram: all accessible.
   - Visit Digikala: domestic fast latency (<20ms).
2. Connect phone to `ZL-5G`:
   - Verify independent browsing via X28's Mihomo.
3. Temporarily stop sing-box on AX3000T:
   - Confirm `ZL-5G` continues working with zero degradation.
   - Restart sing-box on AX3000T.

- [ ] **Step 3: Power-Race Simulation Test**

Simulate unsynchronized bootup:
1. Issue reboot on X28 (`reboot`).
2. Issue reboot on AX3000T simultaneously.
3. Observe AX3000T is fully booted at T+45s with `XI-5G` active.
4. Observe X28 completes 5G bearer initialization at T+150s.
5. Verify at T+160s that internet on `XI-5G` immediately flows without touching either device, with zero crashes, zero reboot loops, and zero manual commands.

- [ ] **Step 4: Commit test artifacts and final status update**

```bash
git add router/tests/
git commit -m "test: add dual-router resilience & auto-port test suite"
```
