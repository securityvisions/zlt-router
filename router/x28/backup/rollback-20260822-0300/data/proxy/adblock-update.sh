#!/bin/sh
# adblock-update.sh — refresh the ad/tracker blocklist for dnsmasq.
# Fetches the StevenBlack unified hosts list (prefer the local xray SOCKS
# tunnel, fall back to direct), converts it to dnsmasq address= lines and
# atomically swaps it in, then re-applies dns-fix (full dnsmasq restart).
# On any failure the previous list stays in place (last-known-good).
#
# Canonical copy: router/x28/adblock-update.sh — deploys to
# /data/proxy/adblock/adblock-update.sh.
set -eu

DIR=/data/proxy/adblock
CONF=$DIR/adblock.conf
NEW=$DIR/adblock.conf.new
LOG=$DIR/update.log
SRC="${ADBLOCK_SRC:-https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts}"
MIN="${ADBLOCK_MIN:-20000}"   # sanity floor: refuse a suspiciously small list

log() { echo "$(date '+%F %T') $*" >> "$LOG"; tail -c 4096 "$LOG" > "$LOG.t" 2>/dev/null && mv "$LOG.t" "$LOG"; }

mkdir -p "$DIR"
log "update: fetching $SRC"

# Fetch: try the local crypto engine first (clean route), then direct
if ! curl -sfL -m 90 -x socks5h://192.168.70.1:1080 -o "$DIR/hosts.raw" "$SRC"; then
    log "update: proxy fetch failed, trying direct"
    curl -sfL -m 90 -o "$DIR/hosts.raw" "$SRC" || { log "update: FETCH FAILED, keeping existing list"; rm -f "$DIR/hosts.raw"; exit 1; }
fi

# Convert to dnsmasq address= lines (unique, sane domains only)
awk '/^0\.0\.0\.0 /{d=$2; if (d!="" && d!="localhost" && d ~ /^[a-z0-9][a-z0-9.-]*\.[a-z]{2,}$/) print "address=/"d"/"}' \
    "$DIR/hosts.raw" | sort -u > "$NEW"

n=$(wc -l < "$NEW" 2>/dev/null || echo 0)
if [ "$n" -lt "$MIN" ]; then
    log "update: list too small ($n < $MIN), keeping existing list"
    rm -f "$NEW" "$DIR/hosts.raw"
    exit 1
fi

mv "$NEW" "$CONF"          # atomic swap: dnsmasq never sees a half-written list
rm -f "$DIR/hosts.raw"
touch "$DIR/.last-update"

# Re-apply the DNS config (idempotent, full restart = clean cache)
sh /data/proxy/dns-fix.sh >/dev/null 2>&1 || true

log "update: OK ($n domains)"
echo "adblock-update: OK ($n domains)"
