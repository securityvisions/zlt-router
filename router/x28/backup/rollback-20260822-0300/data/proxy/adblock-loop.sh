#!/bin/sh
# adblock-loop.sh — weekly blocklist refresh without cron.
# procd service body: sleeps an hour between checks, refreshes when the
# last successful update is older than 7 days. Self-heals across reboots
# and clock drift (age-based, not scheduled-time-based).
#
# Canonical copy: router/x28/adblock-loop.sh — deploys to
# /data/proxy/adblock/adblock-loop.sh.
set -u

DIR=/data/proxy/adblock
MAXAGE=$((7*24*3600))

# let the network/proxy settle after boot
sleep 120

while :; do
    age=999999999
    if [ -f "$DIR/.last-update" ]; then
        age=$(( $(date +%s) - $(date -r "$DIR/.last-update" +%s 2>/dev/null || echo 0) ))
    fi
    if [ "$age" -ge "$MAXAGE" ]; then
        sh "$DIR/adblock-update.sh" >> "$DIR/update.log" 2>&1 || true
    fi
    sleep 3600
done
