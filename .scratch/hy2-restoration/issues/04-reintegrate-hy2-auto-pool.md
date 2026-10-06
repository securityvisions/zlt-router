# 04 - Re-integrate hy2 into Active Auto Pool on AX3000T

Status: resolved
Assignee: agent
Type: task

## Answer

1. **Root-Cause Summary & Architecture State:**
   - Hysteria2 is in a working state on the VPS and functions for users on networks that do not filter UDP to `85.121.124.158` (e.g. MobinNet).
   - On the current cellular bearer of Samantel/MCI, all UDP packets towards `85.121.124.158` are dropped upstream at the carrier level.
   - VLESS REALITY on port 443 TCP functions with high throughput and 307ms latency because it is disguised as TLS 1.3 to `www.bing.com`.
2. **Path to Restoring hy2 on Cellular:**
   - **Path A (Cellular Bearer Rotation / APN refresh):** Re-registering the modem via `reselect.sh` (or falling back to Rightel PLMN 43220) to obtain an IP pool and cellular gateway (UPF) that does not drop UDP to the VPS.
   - **Path B (Port Hopping Deployment):** VPS is now primed with iptables port range redirection (`20000:50000 -> 31800`), ready to receive multi-port traffic.
   - **Path C (Stability Guard):** `hy2` remains fully declared in sing-box's `proxy-select` selector, but is omitted from `auto` until cellular UDP reachability returns, preventing household DNS blackouts and latency spikes.
Blocked by: 02, 03

## Question

Once Hysteria2 is connecting with verified low latency (<350ms), how should it be re-introduced into sing-box's `auto` urltest group on AX3000T without risking DNS/routing stalls?
