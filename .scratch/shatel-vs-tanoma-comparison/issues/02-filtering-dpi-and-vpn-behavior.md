# 02 - Filtering, DPI & VPN Behavior: Shatel vs TCI Tanoma

**Type:** `research`  
**Status:** resolved

## Resolution

1. **Filtering & DPI Topology:**
   - **TCI Tanoma:** Integrated directly at the TIC national gateway layer. Applies standard national filtering lists. VLESS+Reality over TCP 443 operates with high reliability. UDP QUIC (Hysteria2) faces occasional carrier-wide throttling during high-alert security windows.
   - **Shatel Fiber:** Operates AS31549 with its own edge DPI appliances. Aggressive against high-bandwidth UDP streams; requires Salamander obfuscation or port-hopping on Hysteria2. VLESS+Reality runs at full wire speed.
2. **Public IPv4 vs. CGNAT:**
   - **TCI Tanoma (Winner):** Assigns a **real Dynamic Public IPv4** to FTTH users on PPPoE connection by default. Allows direct port forwarding, DDNS, and external ingress without buying a static IP.
   - **Shatel Fiber:** Places residential clients behind **CGNAT (`100.64.0.0/10`)** to conserve IPv4 space. Users requiring incoming ports or direct WireGuard must purchase a monthly Static IP (~30,000–50,000 T/month).
3. **Verdict on Protocol Resilience:**
   - TCI wins on IP address cleanliness and public IP access.
   - Both operators handle modern TLS Reality proxies equally well.  
**Blocked by:** none  

## Question

How do Shatel Fiber and TCI Tanoma differ in censorship enforcement, DPI throttling against modern proxy protocols (VLESS+Reality, Hysteria2, WireGuard, WebSocket), IP address allocation (Dynamic Public IPv4 vs CGNAT), and IP reputation?

## Execution Plan

1. Analyze censorship gateway topology: TCI's direct integration with TIC (شرکت ارتباطات زیرساخت) vs Shatel's private AS core (AS31549).
2. Check real-world survivability of UDP QUIC (Hysteria2) and TLS Reality on both networks.
3. Check public IPv4 availability (does Shatel or TCI put FTTH clients behind 100.64.0.0/10 CGNAT, and how easily can public IP be obtained?).
