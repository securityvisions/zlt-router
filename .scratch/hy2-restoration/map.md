# Hysteria2 (hy2) Restoration & Speed Optimization Map

Label: `wayfinder:map`

## Destination

Diagnose the exact failure point of Hysteria2 (UDP transport / port filtering / obfs / firewall / NAT), restore reliable high-speed connection between home routers (AX3000T & X28) and VPS `85.121.124.158`, and integrate hy2 into the active auto-routing pool.

## Notes

- Domain: Hysteria2 protocol (QUIC/UDP), port forwarding, salamander obfuscation, s-ui on VPS, sing-box on AX3000T, mihomo on X28.
- Target endpoints: VPS (`85.121.124.158`), AX3000T (`192.168.1.1`), X28 (`192.168.70.1`).
- Skills to consult: `diagnosing-bugs`, `domain-modeling`, `grilling`.
- Standing preferences: Zero reboots, keep REALITY active as a fallback, ensure fail-safe operation.

## Decisions so far

<!-- the index: one line per closed ticket, enough to judge relevance, then zoom the link for the detail the ticket holds -->

## Not yet specified

- Multi-port hopping (port range or iptables port forwarding) if ISP filters specific UDP port 31800.
- MTU/MSS optimization for QUIC over cellular (MCI 5G NSA).

## Out of scope

- Replacing Hysteria2 with a non-UDP protocol.
- Changing remote VPS provider or IP address.
