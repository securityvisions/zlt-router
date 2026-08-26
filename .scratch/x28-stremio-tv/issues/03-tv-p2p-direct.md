# 03 — TV P2P playback: egress the carrier (direct), not the tunnel

**What to build:** User rejected debrid; wants plain PirateBay-quality torrent
playback to work. Measured 2026-08-26 (Ubuntu 24.04.4 swarm, protocol-level
probe): BitTorrent peers refuse the VPS datacenter IP — 18/18 handshakes
dropped through the tunnel — while the same swarm's Canonical seeder completed
handshake + sent data to the carrier IP. Fix: the TV's P2P TCP (all ports
except web 80/443) RETURNs from the intercept chain and egresses the carrier;
its web traffic (Netflix, Stremio UI, Torrentio API) keeps riding the tunnel.
Keeper loop asserts the rule every cycle (WAN events rebuild chains).

**Blocked by:** None.

**Status:** claimed

- [x] Probe evidence recorded (18/18 dropped via VPS vs handshake+data via carrier)
- [x] tv-p2p-enable.sh: scoped iptables RETURN (-s TV, tcp, ! 80,443), idempotent + verified
- [x] Keeper loop asserts both Steam routes and TV P2P rule every 30 s
- [x] Deployed live; rule present in X28_SPLIT; stale TV conntrack purged
- [x] UDP maximization: TV UDP marked (0x50, LAN/multicast exempt) → fwmark policy rule → dedicated table default via tun — DHT/UDP-trackers ride the tunnel where international UDP always passes
- [ ] Human test: quality click on TV shows loading → playing, conntrack shows MBs on peer ports


## Comments

> 2026-08-26 — maximization pass: 90s live capture during user attempts showed TCP 1141 SYN_SENT (dead peers, normal) but 51 ESTABLISHED (fix working) and 446/559 UDP answered. Remaining gap was discovery: DHT/UDP-trackers raw via carrier got selectively dropped. Extended tv-p2p-enable.sh: TV UDP marked (0x50; LAN + multicast exempt) → fwmark policy rule (pref 16500) → table 17101 default via tun → mihomo tun carries DHT/UDP-trackers through the tunnel (GEOIP,IR stays DIRECT). TCP data path unchanged (carrier-direct). Stale flows purged. Keeper re-asserts everything every 30 s.
