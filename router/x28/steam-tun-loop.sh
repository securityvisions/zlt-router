#!/bin/sh
# steam-tun-loop.sh — keep the Valve tun routes + TV P2P bypass alive.
#
# The vendor network daemon rebuilds policy table 17000 on WAN events
# (bearer bounce, modem re-register), silently wiping routes added there —
# observed live 2026-08-26, one day after the dual-table fix shipped. The
# same events can rebuild the intercept chain, dropping the TV P2P bypass
# (peers refuse the VPS IP; the TV's P2P must egress the carrier — see
# tv-p2p-enable.sh). Both enablers are idempotent and self-verifying, so
# re-running them every interval is the whole job.
#
# Env seam for tests/tuning: STEAM_TUN_KEEPALIVE (seconds, default 30).
# Canonical copy: router/x28/steam-tun-loop.sh — deploys to /data/proxy/.

while :; do
    sh /data/proxy/steam-tun-enable.sh >/dev/null 2>&1 || true
    sh /data/proxy/tv-p2p-enable.sh   >/dev/null 2>&1 || true
    sleep "${STEAM_TUN_KEEPALIVE:-30}"
done
