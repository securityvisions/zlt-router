#!/bin/sh
# media-gateway.sh — Unified Smart TV control & IPTV HLS proxy engine.
#
# Consolidates:
#   1. Samsung Q70C TV lifecycle: WOL packet dispatch and Tizen REST API polling.
#   2. Telewebion HLS live edge discovery and 45-second edge URL caching.
#   3. Real-time manifest rewriter:
#      - Sanitizes EXT-X-MEDIA-SEQUENCE 64-bit timestamps down to 9 digits to
#        prevent 32-bit integer overflow crash on Tizen OS 9.0 AVPlay.
#      - Prepends dynamic live edge URLs to chunk references.
#   4. Master adaptive-bitrate M3U8 generation (480p, 720p, 1080p).
#
# Interfaces:
#   media-gateway.sh tv status [--json]
#   media-gateway.sh tv wake
#   media-gateway.sh manifest <slug> [res]
#   media-gateway.sh master <slug>
#   media-gateway.sh sanitize <input_file_or_stdin>
#   media-gateway.sh rewrite <base_url> <input_file_or_stdin>
#   media-gateway.sh cgi-media
#   media-gateway.sh cgi-stream

set -u

TV_IP="${TV_IP:-192.168.1.105}"
TV_MAC="${TV_MAC:-c8:12:0b:32:7c:f2}"
CACHE_DIR="${IPTV_CACHE_DIR:-/tmp/iptv_cache}"
ROUTER_IP="${ROUTER_IP:-192.168.1.1}"

# Pure filter: Sanitize 64-bit sequence numbers down to 9 digits to avoid Tizen integer overflow
mg_sanitize_sequence() {
    sed -E 's/EXT-X-MEDIA-SEQUENCE:[0-9]{7}([0-9]{9})/EXT-X-MEDIA-SEQUENCE:\1/'
}

# Pure filter: Rewrite manifest chunk paths with absolute edge prefix
mg_rewrite_manifest() {
    local base="$1"
    mg_sanitize_sequence | awk -v p="${base}/" '
        /^[0-9a-zA-Z_-]+\.ts/ { print p $0; next }
        { print }
    '
}

# Pure generator: Master adaptive-bitrate playlist
mg_master_playlist() {
    local slug="$1"
    cat <<EOF
#EXTM3U
#EXT-X-VERSION:6
#EXT-X-STREAM-INF:BANDWIDTH=1240800,RESOLUTION=854x480,CODECS="avc1.4d401f,mp4a.40.2"
http://${ROUTER_IP}/cgi-bin/media/${slug}/480p.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1861200,RESOLUTION=1280x720,CODECS="avc1.4d401f,mp4a.40.2"
http://${ROUTER_IP}/cgi-bin/media/${slug}/720p.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2756600,RESOLUTION=1920x1080,CODECS="avc1.4d4028,mp4a.40.2"
http://${ROUTER_IP}/cgi-bin/media/${slug}/1080p.m3u8
EOF
}

# TV status
mg_tv_status() {
    local fmt="${1:-text}"
    local info name model state="off"

    if ping -c 1 -W 1 "$TV_IP" >/dev/null 2>&1; then
        info=$(curl -sk -m 2 "http://${TV_IP}:8001/api/v2/" 2>/dev/null || true)
        if [ -n "$info" ]; then
            state="on"
            name=$(printf '%s' "$info" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p' | head -1)
            model=$(printf '%s' "$info" | sed -n 's/.*"modelName":"\([^"]*\)".*/\1/p' | head -1)
        else
            state="standby"
        fi
    fi

    if [ "$fmt" = "--json" ] || [ "$fmt" = "json" ]; then
        printf '{"ip":"%s","mac":"%s","state":"%s","name":"%s","model":"%s"}\n' \
            "$TV_IP" "$TV_MAC" "$state" "${name:-Samsung Q70C}" "${model:-Q70C}"
    else
        echo "state=$state"
        echo "ip=$TV_IP"
        echo "mac=$TV_MAC"
        [ -n "${name:-}" ] && echo "name=$name"
        [ -n "${model:-}" ] && echo "model=$model"
    fi
}

# TV wake
mg_tv_wake() {
    if command -v etherwake >/dev/null 2>&1; then
        etherwake -i br-lan "$TV_MAC" 2>/dev/null || etherwake "$TV_MAC" 2>/dev/null || true
    fi
    echo "wake_packet_sent=$TV_MAC"
}

# Resolve live Telewebion edge base URL
mg_resolve_edge() {
    local real_slug="$1"
    mkdir -p "$CACHE_DIR" 2>/dev/null || true
    local edge_file="$CACHE_DIR/edge_${real_slug}"
    local now edge_ts base=""

    now=$(date +%s)
    if [ -f "$edge_file" ]; then
        edge_ts=$(cat "${edge_file}.ts" 2>/dev/null || echo 0)
        if [ $((now - edge_ts)) -lt 45 ]; then
            base=$(cat "$edge_file" 2>/dev/null || true)
        fi
    fi

    if [ -z "$base" ]; then
        local final
        final=$(curl -sk -m 4 -o /dev/null -w '%{url_effective}' -L "https://ncdn.telewebion.net/${real_slug}/live/playlist.m3u8" 2>/dev/null || true)
        base="${final%/*}"
        if [ -n "$base" ] && [ "$final" != "https://ncdn.telewebion.net/${real_slug}/live/playlist.m3u8" ]; then
            echo "$base" > "$edge_file" 2>/dev/null || true
            echo "$now" > "${edge_file}.ts" 2>/dev/null || true
        fi
    fi

    echo "$base"
}

# Serve manifest with headers
mg_serve_manifest() {
    local slug="$1"
    local res="${2:-720p}"
    local real_slug="$slug"
    [ "$slug" = "tamasha" ] && real_slug="hdtest"

    mkdir -p "$CACHE_DIR" 2>/dev/null || true
    local now manifest_cache m_ts base
    now=$(date +%s)
    manifest_cache="$CACHE_DIR/m_${real_slug}_${res}.m3u8"

    if [ -f "$manifest_cache" ]; then
        m_ts=$(cat "${manifest_cache}.ts" 2>/dev/null || echo 0)
        if [ $((now - m_ts)) -le 1 ]; then
            printf "Content-Type: application/vnd.apple.mpegurl; charset=utf-8\r\n"
            printf "Access-Control-Allow-Origin: *\r\n"
            printf "Cache-Control: no-cache\r\n\r\n"
            cat "$manifest_cache"
            return 0
        fi
    fi

    base=$(mg_resolve_edge "$real_slug")
    if [ -z "$base" ]; then
        printf "Status: 502 Bad Gateway\r\n"
        printf "Content-Type: text/plain\r\n\r\n"
        echo "Failed to resolve live edge for $slug"
        return 1
    fi

    local tmp="${manifest_cache}.tmp.$$"
    if curl -sk -m 4 "${base}/${res}/index.m3u8" 2>/dev/null | mg_rewrite_manifest "${base}/${res}" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
        mv -f "$tmp" "$manifest_cache" 2>/dev/null || true
        echo "$now" > "${manifest_cache}.ts" 2>/dev/null || true
        printf "Content-Type: application/vnd.apple.mpegurl; charset=utf-8\r\n"
        printf "Access-Control-Allow-Origin: *\r\n"
        printf "Cache-Control: no-cache\r\n\r\n"
        cat "$manifest_cache"
    else
        rm -f "$tmp" 2>/dev/null || true
        printf "Status: 502 Bad Gateway\r\n"
        printf "Content-Type: text/plain\r\n\r\n"
        echo "Failed to fetch stream manifest for $slug ($res)"
        return 1
    fi
}

# CGI Entrypoint for /cgi-bin/media
mg_cgi_media() {
    local path="${PATH_INFO:-}"
    path="${path#/}"
    local slug="${path%%/*}"
    local res="${path##*/}"
    res="${res%.m3u8}"
    [ -z "$res" ] && res="720p"
    [ -z "$slug" ] && slug="irinn"

    mg_serve_manifest "$slug" "$res"
}

# CGI Entrypoint for /cgi-bin/stream
mg_cgi_stream() {
    local slug
    slug=$(basename "${PATH_INFO:-}" .m3u8)
    [ -z "$slug" ] && slug="${QUERY_STRING:-irinn}"

    printf "Content-Type: application/vnd.apple.mpegurl; charset=utf-8\r\n"
    printf "Access-Control-Allow-Origin: *\r\n"
    printf "Cache-Control: no-cache\r\n\r\n"
    mg_master_playlist "$slug"
}

# Main CLI dispatch
case "${1:-}" in
    tv)
        shift
        case "${1:-status}" in
            wake|on) mg_tv_wake ;;
            status) shift; mg_tv_status "$@" ;;
            *) echo "usage: media-gateway.sh tv {wake|status}" ;;
        esac
        ;;
    manifest)
        shift
        mg_serve_manifest "${1:-irinn}" "${2:-720p}"
        ;;
    master)
        shift
        mg_master_playlist "${1:-irinn}"
        ;;
    sanitize)
        shift
        if [ $# -gt 0 ] && [ -f "$1" ]; then
            mg_sanitize_sequence < "$1"
        else
            mg_sanitize_sequence
        fi
        ;;
    rewrite)
        shift
        base="$1"
        shift
        if [ $# -gt 0 ] && [ -f "$1" ]; then
            mg_rewrite_manifest "$base" < "$1"
        else
            mg_rewrite_manifest "$base"
        fi
        ;;
    cgi-media)
        mg_cgi_media
        ;;
    cgi-stream)
        mg_cgi_stream
        ;;
    *)
        if [ -n "${REQUEST_METHOD:-}" ]; then
            mg_cgi_media
        else
            echo "usage: media-gateway.sh {tv|manifest|master|sanitize|rewrite|cgi-media|cgi-stream}"
        fi
        ;;
esac
