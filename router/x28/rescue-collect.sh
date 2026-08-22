#!/bin/sh
# rescue-collect.sh — Telegram public-config fetcher (rescue pool, stage B).
#
# Fetches t.me/s/<channel> web previews THROUGH THE TUNNEL only, extracts
# supported proxy URIs, merges into the raw cache (dedupe, cap 300).
# Age-gated (default 6 h) and tunnel-gated: ISP-mode DNS => logged skip.
#
# Modes:
#   collect        — gated fetch+merge (loop body)
#   extract <file> — pure extraction from a saved HTML/preview file (tests)
#   status         — cache size + last-fetch age
#
# Env seams: RESCUE_DIR, RAW_CAP, FETCH_AGE_H, FETCH_CMD (test seam),
#            SOCKS (default socks5h://192.168.70.1:1080), NOW override.
set -u

RESCUE_DIR="${RESCUE_DIR:-/data/proxy/rescue}"
RAW="$RESCUE_DIR/raw/collected.txt"
CHANNELS="${CHANNELS_FILE:-$RESCUE_DIR/channels.txt}"
SOCKS="${SOCKS:-socks5h://192.168.70.1:1080}"
DNS_CONF="${DNS_CONF:-/tmp/dnsmasq.conf}"
RAW_CAP="${RAW_CAP:-300}"
FETCH_AGE_H="${FETCH_AGE_H:-6}"
SWEEP_MAX="${SWEEP_MAX:-300}"   # hard wall-clock cap for one full sweep
NOW="${NOW:-$(date +%s)}"
LOGF="$RESCUE_DIR/collect.log"

mkdir -p "$RESCUE_DIR/raw" 2>/dev/null
log() { echo "$(date '+%F %T') $*" >> "$LOGF" 2>/dev/null; }

EXTRACT_RE='(vless|vmess|trojan|ss|hysteria2|hy2|tuic|juicity)://[A-Za-z0-9+/=_?#&:@.%~-]+'

extract() {  # extract <htmlfile> — print URIs found, one per line
    grep -oE "$EXTRACT_RE" "$1" 2>/dev/null || true
}

fetch_channel() {  # fetch_channel <channel> -> stdout URIs or nothing
    local ch="$1" tmp
    tmp=$(mktemp 2>/dev/null) || return 0
    if [ -n "${FETCH_CMD:-}" ]; then
        $FETCH_CMD "$ch" > "$tmp" 2>/dev/null
    else
        curl -sS -m 12 -x "$SOCKS" "https://t.me/s/$ch" > "$tmp" 2>/dev/null
    fi
    [ -s "$tmp" ] && extract "$tmp"
    rm -f "$tmp"
}

tunnel_ok() {
    grep -q 'server=127.0.0.1#5353' "$DNS_CONF" 2>/dev/null
}

collect() {
    [ -r "$CHANNELS" ] || { log "no channels file"; return 0; }
    lastrun=0
    [ -f "$RESCUE_DIR/last-fetch" ] && lastrun=$(cat "$RESCUE_DIR/last-fetch" 2>/dev/null || echo 0)
    case "$lastrun" in ''|*[!0-9]*) lastrun=0 ;; esac
    [ $(( NOW - lastrun )) -lt $(( FETCH_AGE_H * 3600 )) ] && return 0

    if ! tunnel_ok; then
        log "skip: dns not in tunnel mode (no VPN to reach Telegram)"
        return 0
    fi

    newf=$(mktemp 2>/dev/null) || return 0
    n=0
    t0=$(date +%s)
    while IFS= read -r ch; do
        [ -n "$ch" ] || continue
        _n=$(date +%s); [ $(( _n - t0 )) -gt "$SWEEP_MAX" ] && { log "sweep deadline hit at channel $ch"; break; }
        fetch_channel "$ch" >> "$newf" || true
        sleep "${CH_DELAY:-1}"
    done < "$CHANNELS"

    merged=$(mktemp 2>/dev/null)
    { cat "$RAW" 2>/dev/null; cat "$newf"; } | sort -u | head -"$RAW_CAP" > "$merged"
    before=0; [ -f "$RAW" ] && before=$(wc -l < "$RAW")
    after=$(wc -l < "$merged")
    mv "$merged" "$RAW"
    rm -f "$newf"
    echo "$NOW" > "$RESCUE_DIR/last-fetch"
    log "sweep done: channels-scanned, +$((after - before)) new (total $after)"
}

case "${1:-collect}" in
    collect) collect ;;
    extract) extract "$2" ;;
    status)
        c=0; [ -f "$RAW" ] && c=$(wc -l < "$RAW")
        lr="never"
        if [ -f "$RESCUE_DIR/last-fetch" ]; then _n=$(date +%s); _l=$(cat "$RESCUE_DIR/last-fetch"); case "$_l" in ""|*[!0-9]*) _l=0 ;; esac; lr="$(( (_n - _l) / 60 )) min ago"; fi
        echo "raw=$c last-fetch=$lr cap=$RAW_CAP"
        ;;
    *) echo "usage: rescue-collect.sh [collect|extract FILE|status]" >&2; exit 2 ;;
esac
exit 0
