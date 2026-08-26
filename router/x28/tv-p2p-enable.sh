#!/bin/sh
# tv-p2p-enable.sh — maximize the TV's torrent reachability.
#
# Measured 2026-08-26: BitTorrent peers refuse the VPS datacenter IP
# (18/18 handshakes dropped through the tunnel) but fully accept the
# carrier IP (handshake + bitfield). Two-part maximization:
#   TCP  — P2P peer connections bypass the transparent proxy and egress
#          the carrier directly (all ports except web 80/443: Netflix,
#          Stremio UI/API keep riding the tunnel).
#   UDP  — DHT discovery + UDP trackers ride the engine tun (via the
#          tunnel, where international UDP always passes); the carrier's
#          selective UDP filtering no longer starves peer discovery.
#          uTP data through the tunnel may be refused by blocklisted
#          peers — engines fall back to the working TCP peers.
# Local destinations (LAN, multicast) are exempt from the UDP hijack.
# All parts idempotent and self-verifying; WAN events can wipe both the
# policy table and firewall rules, so the keeper loop re-asserts these.
#
# Env seams for tests: IPT_BIN, IP_BIN, TV_IP, P2P_CHAIN, P2P_MARK, P2P_TABLE.
# Canonical copy: router/x28/tv-p2p-enable.sh — deploys to /data/proxy/.

TV_IP="${TV_IP:-192.168.70.155}"
IPT="${IPT_BIN:-iptables}"
IPC="${IP_BIN:-ip}"
CHAIN="${P2P_CHAIN:-X28_SPLIT}"
MARK="${P2P_MARK:-0x50}"
TABLE="${P2P_TABLE:-17101}"
RULE="-s $TV_IP -p tcp -m multiport ! --dports 80,443 -j RETURN"

# ── TCP: P2P egresses the carrier ────────────────────────────────────────────
if ! $IPT -t nat -C "$CHAIN" $RULE 2>/dev/null; then
    $IPT -t nat -I "$CHAIN" 1 $RULE || { echo "ERROR: cannot insert TV P2P bypass into $CHAIN" >&2; exit 1; }
fi
$IPT -t nat -C "$CHAIN" $RULE 2>/dev/null \
  || { echo "ERROR: TV P2P bypass missing in $CHAIN after insert." >&2; exit 1; }

# ── UDP: DHT/discovery rides the engine tun ──────────────────────────────────
# exempt LAN + multicast, then mark; policy rule sends marked packets to a
# dedicated table whose default is the tun
$IPT -t mangle -C PREROUTING -d 192.168.0.0/16 -j RETURN 2>/dev/null \
  || $IPT -t mangle -I PREROUTING 1 -d 192.168.0.0/16 -j RETURN
$IPT -t mangle -C PREROUTING -d 224.0.0.0/4 -j RETURN 2>/dev/null \
  || $IPT -t mangle -I PREROUTING 1 -d 224.0.0.0/4 -j RETURN
$IPT -t mangle -C PREROUTING -s "$TV_IP" -j MARK --set-mark "$MARK" 2>/dev/null \
  || $IPT -t mangle -I PREROUTING 1 -s "$TV_IP" -j MARK --set-mark "$MARK"

$IPC rule show 2>/dev/null | grep -qF "fwmark $MARK lookup $TABLE" \
  || $IPC rule add fwmark "$MARK" lookup "$TABLE" priority 16500
$IPC route show table "$TABLE" 2>/dev/null | grep -qF "default dev utun" \
  || $IPC route add default dev utun table "$TABLE"

$IPC rule show 2>/dev/null | grep -qF "fwmark $MARK lookup $TABLE" \
  || { echo "ERROR: fwmark policy rule missing after add." >&2; exit 1; }
$IPC route show table "$TABLE" 2>/dev/null | grep -qF "default dev utun" \
  || { echo "ERROR: tun default route missing in table $TABLE after add." >&2; exit 1; }

exit 0
