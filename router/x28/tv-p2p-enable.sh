#!/bin/sh
# tv-p2p-enable.sh — let the TV's peer-to-peer traffic egress the carrier.
#
# Measured 2026-08-26: BitTorrent peers refuse the VPS datacenter IP
# (18/18 handshakes dropped through the tunnel) but fully accept the
# carrier IP (handshake + bitfield). So the TV's P2P TCP must bypass the
# transparent proxy; its web traffic (Netflix, Stremio UI/API on 80/443)
# keeps riding the tunnel. Idempotent, self-verifying.
#
# Env seams for tests: IPT_BIN, TV_IP, P2P_CHAIN.
# Canonical copy: router/x28/tv-p2p-enable.sh — deploys to /data/proxy/.

TV_IP="${TV_IP:-192.168.70.155}"
IPT="${IPT_BIN:-iptables}"
CHAIN="${P2P_CHAIN:-X28_SPLIT}"
RULE="-s $TV_IP -p tcp -m multiport ! --dports 80,443 -j RETURN"

if ! $IPT -t nat -C "$CHAIN" $RULE 2>/dev/null; then
    $IPT -t nat -I "$CHAIN" 1 $RULE || { echo "ERROR: cannot insert TV P2P bypass into $CHAIN" >&2; exit 1; }
fi

# verify it landed (chain rebuilds can race the insert)
$IPT -t nat -C "$CHAIN" $RULE 2>/dev/null \
  || { echo "ERROR: TV P2P bypass missing in $CHAIN after insert." >&2; exit 1; }

exit 0
