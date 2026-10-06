# 02 - Configure Sing-Box URLTest & via-x28 Outbound on AX3000T

**Type:** `task`  
**Status:** resolved

## Resolution

Configured automated URLTest failover and mesh backup outbound in AX3000T's `/etc/sing-box/config.json`:
1. **Added `via-x28` Outbound:** SOCKS5 outbound pointing to X28 CPE proxy on `192.168.70.1:1080`, allowing AX3000T to route through X28's rescue pool if direct VPS connections fail.
2. **Hardened `auto` URLTest Group:**
   - Outbounds: `["vps-reality", "hy2", "via-x28", "cdn-ws"]`
   - `url: "https://www.gstatic.com/generate_204"`
   - `interval: "30s"`, `tolerance: 50`
   - `interrupt_exist_connections: true` (terminates hanging sockets immediately when switching nodes).
3. **Selector & Routing Alignment:**
   - Added `"auto"` to `proxy-select` and set active selection to `"auto"`.
   - Verified live probe returns HTTP 204.  
**Blocked by:** 01  

## Question

How to ensure the AX3000T automatically selects healthy proxy nodes without manual Clash API PUT calls, and seamlessly falls back to X28's local SOCKS proxy if VPS direct routes fail?

## Execution Plan

1. In `/etc/sing-box/config.json`:
   - Add outbound `via-x28` (`type: "socks"`, `server: "192.168.70.1"`, `server_port: 1080`).
   - Configure `auto` group with:
     - Outbounds: `["vps-reality", "hy2", "via-x28", "cdn-ws"]`
     - `url: "https://www.gstatic.com/generate_204"`
     - `interval: "30s"`
     - `tolerance: 50`
     - `interrupt_exist_connections: true`
   - Set `proxy-select` default to `auto`, and point routing rules to `auto`.
2. Validate syntax using `sing-box check -c /etc/sing-box/config.json`.
3. Reload sing-box and verify outbound selection via API.
