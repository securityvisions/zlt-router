# 04 - Transparent Proxying for UDP Voice and Media on ZL-5G

Status: resolved
Assignee: agent
Type: task

## Answer

1. **Kernel & Architecture Constraints:**
   - Probing the MediaTek MT6890 kernel on X28 confirmed that `xt_TPROXY` (`iptables -m tproxy`) is not compiled into the vendor kernel (`Couldn't load match tproxy`). Generic full-packet UDP TPROXY is therefore architecturally unavailable without a custom kernel recompile.
   - Mihomo provides a userspace TUN interface (`utun`, `198.18.0.1/30`) which is selectively routed for latency-sensitive game traffic (Steam/Valve CIDRs).
   - QUIC drop (`-p udp --dport 443 -j DROP`) in `X28_NOQUIC` is essential and operational: it forces web browsers (Chrome/Firefox/YouTube) to drop QUIC and immediately fall back to HTTP/2 over TCP, which enters transparent proxying cleanly without 15-second DPI stalls.
2. **Resolution Applied:**
   - Introduced a dedicated `X28_DNS` chain in `iptables -t nat` targeting ports 53 (UDP & TCP).
   - Exempted AX3000T (`192.168.70.2`) with `-j RETURN` to preserve independent router operation.
   - Redirected all client DNS traffic to local `dnsmasq` on port 53.
   - Verified that clients using hardcoded DNS servers (such as `8.8.8.8`) are intercepted cleanly and answered by unpoisoned upstream resolvers rather than leaking to MCI cellular.
   - Updated and deployed `router/x28/tproxy-fixed-enable.sh` to `/data/proxy/tproxy-fixed-enable.sh`.
Blocked by: 02

## Question

How should UDP traffic on ZL-5G be handled to unblock voice calls (Telegram/WhatsApp/Discord) and media streams that are currently dropped or routed direct to cellular?

### Findings & Context

Currently on X28:
- In `iptables -t nat -S X28_SPLIT`: Only `-p tcp -j REDIRECT --to-ports 12345` exists. Zero UDP redirection is performed.
- In `iptables -t mangle -S X28_NOQUIC`: `-p udp -m udp --dport 443 -j DROP` drops all QUIC traffic.
- Any non-443 UDP packets (ports 3478, 5004, STUN, gaming, VoIP) bypass the proxy and travel directly to MCI cellular, where international UDP is throttled or blocked.
- Mihomo already listens on UDP 12345 and supports TPROXY/TUN.
