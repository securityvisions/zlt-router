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
- [ ] Human test: quality click on TV shows loading → playing, conntrack shows MBs on peer ports
