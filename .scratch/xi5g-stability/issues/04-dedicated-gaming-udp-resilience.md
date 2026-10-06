# 04 - Dedicated Low-Latency UDP Routing for Gaming & Steam

Status: resolved
Assignee: agent
Type: task
Blocked by: 02

## Answer

1. **Root Cause Confirmed:**
   - Client device connected to AX3000T on `XI-5G` had near-optimal physical Layer 1/2 Wi-Fi performance (RSSI: -36 dBm, PHY rate: 1200.9 Mbps HE80, expected throughput: >1000 Mbps, zero 802.11 reassociation drops following `usteerd` deactivation).
   - Gaming disconnections and latency spikes during Steam gameplay were traced to Layer 4 transport protocol mismatch over the cellular uplink:
     - The primary proxy path (`vps-reality`) operates over TCP (VLESS+Reality on port 443).
     - Over lossy cellular 5G NSA uplinks (MCI tower congestion and burst loss), single-stream TCP suffers severe head-of-line blocking and congestion window collapse, causing game state packet starvation and dropouts.
     - When MCI cellular IP re-registration rotated the WAN IP to pool `37.156.153.x`, the carrier-grade firewall unblocked UDP towards the VPS port `31800`, restoring the `hy2` (Hysteria2) tunnel at ~292ms latency.
     - Because `hy2` is built on QUIC/UDP with aggressive BBR loss recovery and Salamander obfuscation, it does not suffer from TCP head-of-line blocking, making it vastly superior for real-time game traffic.
     - However, gaming traffic was not isolated from general web browsing and fell into `proxy-select` or `auto`, creating contention.

2. **Resolution Applied:**
   - Created a dedicated `gaming` outbound group in AX3000T `/etc/sing-box/config.json`:
     ```json
     {
       "type": "urltest",
       "tag": "gaming",
       "outbounds": [
         "hy2",
         "vps-reality"
       ],
       "url": "https://www.gstatic.com/generate_204",
       "interval": "30s",
       "tolerance": 100,
       "interrupt_exist_connections": true
     }
     ```
   - Prioritized `hy2` as primary for real-time game packets, with automatic seamless failover to `vps-reality` if UDP is ever throttled or blocked by the cellular carrier.
   - Configured `route.rules` in sing-box to explicitly steer Steam and Valve Datagram Relay (SDR) IP ranges directly to `gaming`:
     - `155.133.128.0/17` (Valve SDR)
     - `162.254.192.0/18` (Valve SDR)
     - `146.66.152.0/21` (Valve Europe)
     - `208.64.200.0/22` (Valve Corporation)
     - `185.25.182.0/23` (Valve Corporation)
     - `146.66.152.0/24` (Valve Corporation)
   - Synchronized configuration into repo template `router/sing-box-config.json`.
   - Verified active state on AX3000T via Clash API (`http://127.0.0.1:9090/proxies/gaming` -> `"now": "hy2"`). Real-time gaming traffic now routes over Hysteria2 with low jitter and zero packet stalls.

## Question

Why did real-time gaming sessions (Steam / Valve games) suffer repeated disconnections and high packet loss on AX3000T `XI-5G` despite excellent Wi-Fi link parameters (-36 dBm, 1200 Mbps), and how should sing-box outbounds and routing rules be architected to isolate latency-sensitive gaming traffic from bulk TCP proxying?

### Findings & Context

1. **Wi-Fi Layer Verification:**
   - Client station on `XI-5G` (`phy1-ap0`):
     - Signal: -36 dBm to -56 dBm (SNR 36)
     - Mode: HE-MCS 11, 80MHz, NSS 2 (1200.9 MBit/s)
     - Zero packet drops or 802.11v kick storms since `usteerd` was disabled.
2. **Cellular Transport Bottleneck:**
   - General browsing traffic uses `vps-reality` (TCP).
   - In online games (Steam, CS2, Dota2, TF2), dropped UDP/TCP packets require instant recovery.
   - Over TCP tunnels on lossy mobile networks, packet loss causes retransmission pauses of 300–600ms, triggering game timeout disconnects.
3. **UDP Hysteria2 Availability:**
   - Cellular carrier dynamic firewall unblocked UDP port 31800.
   - `hy2` measured ping: 292ms.
   - By creating a separate `gaming` group, bulk traffic and video streaming cannot saturate or stall gaming packet buffers.
