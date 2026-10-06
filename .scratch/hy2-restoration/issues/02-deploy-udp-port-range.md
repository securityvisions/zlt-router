# 02 - Deploy UDP Port Range & Alternative Ports on VPS

Status: resolved
Assignee: agent
Type: task

## Answer

1. **Port Redirection Configured on VPS:**
   - Redirected UDP port ranges `20000:50000`, `443`, and `19302` to internal Hysteria2 port `31800` via iptables PREROUTING on the VPS.
   - Allowed all corresponding UDP ports in UFW firewall.
2. **Finding:**
   - Testing 15 diverse UDP ports (`53, 80, 123, 443, 500, 1194, 2053, 2083, 3478, 4500, 5060, 8443, 10000, 19302`) simultaneously with UFW disabled demonstrated that MCI's filtering towards `85.121.124.158` is IP-wide for UDP, rather than restricted to port 31800.
   - Sing-box's port hopping (`server_ports: ["20000:50000"]`) is confirmed natively supported in sing-box 1.13 and ready once UDP reachability to the VPS IP is restored.
Blocked by: 01

## Question

Can Hysteria2 connect if traffic is forwarded from standard or alternative ports (e.g. 443/udp, 8443/udp, or multi-port hopping range `20000:40000`) on the VPS to internal port 31800?

### Findings & Context

1. Standard QUIC port is 443/udp, which cellular networks allow for web browsing.
2. Hysteria2 supports port ranges (e.g. `20000-40000:31800` or `8443:31800` via iptables `PREROUTING -p udp -m multiport --dports ... -j REDIRECT --to-ports 31800`).
3. If MCI is blocking port 31800 specifically, port redirection on VPS will immediately restore connectivity.
