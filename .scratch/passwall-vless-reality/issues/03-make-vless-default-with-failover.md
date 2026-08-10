# 03 — Make VLESS the default with hysteria auto-failover

**What to build:** The default proxy path switches to the new VLESS+REALITY node while it is healthy, and automatically fails over to the hysteria2 node when the VLESS node drops, restoring to VLESS when it recovers. Implemented as a URLTest node (the VLESS node + the hysteria2 node as members) set as the global TCP node; UDP keeps following TCP. The existing shunt/socks configurations are left untouched.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] Global TCP node is set to the URLTest failover node; UDP node follows TCP
- [ ] The generated proxy config contains the URLTest outbound listing both member nodes
- [ ] A proxy probe through the router's SOCKS port returns 204
- [ ] The firewall redirect chains are intact and the proxy log shows no errors
- [ ] Failover behavior is demonstrated: with the VLESS member unreachable, traffic still succeeds via hysteria; with it restored, VLESS is used again
