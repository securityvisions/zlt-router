# 01 - Isolate UDP Transport Failure on Port 31800

Status: resolved
Assignee: agent
Type: task

## Answer

1. **Empirical 3-Hop Packet Trace:**
   - Configured simultaneous packet counters on AX3000T, X28, and VPS:
     - Hop 1 (AX3000T): Sing-box transmitted QUIC UDP packets on `lan4` to X28 gateway `192.168.70.1`.
     - Hop 2 (X28): Mangle PREROUTING and FORWARD chains counted 8 packets (10,528 bytes) forwarded to cellular modem interface `ccmni1`.
     - Hop 3 (VPS `85.121.124.158`): `tcpdump` with UFW stopped received 0 packets.
   - Tested foreign STUN UDP against `stun.l.google.com:19302`: succeeded in 130ms, proving general UDP outbound from the cellular modem works.
   - Proved that the Iranian mobile carrier (MCI / Samantel PLMN 43211) is specifically blacklisting/dropping all direct outbound UDP packets destined to VPS IP `85.121.124.158`.
2. **MobinNet Client Comparison:**
   - Meanwhile, client `tape` connecting from MobinNet (`103.132.228.234`) to the same VPS on `31800/udp` streams YouTube continuously with zero packet loss, proving the VPS server and s-ui inbound are 100% healthy.
Blocked by: none

## Question

Why are UDP packets on port 31800 failing to reach VPS `85.121.124.158` from the home network, while client `103.132.228.234` communicates with Hysteria2 on the same port without issue?

### Findings & Context

1. On the VPS (`85.121.124.158`), `ss -ulpn | grep 31800` confirms `sui` listens on `*:31800`.
2. UFW on VPS has `31800/udp ALLOW Anywhere`.
3. Running `tcpdump -ni any 'port 31800'` on VPS shows active inbound and outbound traffic with client `103.132.228.234`.
4. However, UDP packets sent from our home cellular gateway (X28 public IP `37.156.153.153` / `31.171.100.165`) towards `85.121.124.158:31800` produce zero received packets on the VPS interface.
5. In Iran, mobile operators (MCI / Samantel / Irancell) frequently deploy stateful UDP filtering or port-specific throttles on non-standard high ports like 31800.
