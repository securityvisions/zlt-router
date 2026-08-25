# 02 — All-UDP transparent proxy (TPROXY)

**What to build:** LAN UDP flows enter the proxy engine via a TPROXY listener so the engine's rules decide the path — Iranian UDP stays DIRECT (GEOIP), foreign UDP (Steam voice) exits via the VPS. The engine gains a UDP tproxy port, the firewall gains a mangle TPROXY chain (with returns for the VPS IP, the LAN, multicast and broadcast so DHCP/mDNS/DNS keep working) plus the fwmark/ip-rule/local-table route, and a persistable toggle script (enable/disable, boot-safe) restores the old TCP-only behavior cleanly. The QUIC drop stays in force.

**Blocked by:** 01 — UDP-path diagnostic (only proceeds if 01 confirms direct UDP is filtered).

**Status:** wontfix

- [ ] Engine config gains a UDP tproxy port (TCP redir untouched)
- [ ] Enable script idempotently installs the mangle chain + fwmark rule + local-table route; returns protect DHCP/mDNS/DNS/local traffic
- [ ] Disable script removes exactly what enable added (verified cleanup)
- [ ] Fixture tests: enable issues the TPROXY rule/route sequence; disable reverts it (stubbed iptables/ip)
- [ ] Live: UDP sessions visible in the engine controller; Steam voice joins; local UDP unaffected; toggle reverts cleanly
  - _Design change (2026-08-24):_ this iptables build (1.8.3 legacy) has no
    xt_TPROXY target and no nftables, so the firewall TPROXY path is
    impossible. Pivoted to mihomo TUN (gvisor stack, /dev/net/tun present):
    a scoped route sends Valve/Steam CIDRs through the engine's tun device —
    Steam voice UDP+TCP proxied, every other LAN flow untouched. The enable/
    disable toggle now manages `ip route add/del <valve-cidrs> dev utun`.

## Answer

Superseded by design change before implementation: this vendor kernel ships no xt_TPROXY (iptables 1.8.3 legacy, no nftables), so an all-UDP tproxy path was not buildable here. Replacement: the engine's own TUN (gvisor) carries UDP transparently; scope narrowed from all-LAN-UDP to Valve CIDRs only. See 03 + 04/05.
