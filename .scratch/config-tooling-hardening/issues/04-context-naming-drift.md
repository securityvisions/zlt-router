# 04 - Fix CONTEXT.md naming drift

Status: resolved
Type: task

## Question

Align the glossary with deployed reality (Sept 16 review, "mini-card"):

1. X28 entry says "v2rayA + xray-core" — deployed engine is mihomo. Correct the term.
2. Hysteria2 entry still cites the "SOCKS port 1070" probe contract — replace with the ProbeService contract (profiles, exit codes, 192.168.70.1:1080).
3. `x28link.sh` exists only as a device-side rename on AX3000T's /root — document where it actually lives.
4. Cross-check every remaining CONTEXT.md entry against the deployed device state (one pass).

## Answer

Fixed in CONTEXT.md:
1. X28 entry: "v2rayA + xray-core" → mihomo engine (SOCKS 192.168.70.1:1080, DNS 127.0.0.1:5353).
2. Crypto engine entry: xray-core/x28proxy init script marked superseded by mihomo.
3. Link entry: linkstate.sh lives at /data/proxy/linkstate.sh on X28; /root/x28link.sh is only the AX3000T-side wrapper name.
4. Hysteria2 entry: updated — availability is IP-pool dependent (dead on Sept 15 pool, alive ~292ms after Sept 16 re-registration); the `gaming` urltest group owns the flip.
