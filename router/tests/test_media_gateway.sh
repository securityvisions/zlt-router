#!/bin/sh
# Unit tests for router/media-gateway.sh
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
MG="$HERE/../media-gateway.sh"

PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Test 1: Sequence number sanitization (64-bit to 9-digit)
cat > "$TMP/raw_manifest.m3u8" <<'EOF'
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:6
#EXT-X-MEDIA-SEQUENCE:1726511123456789
#EXTINF:6.000,
chunk_01.ts
#EXTINF:6.000,
chunk_02.ts
EOF

sanitized=$(sh "$MG" sanitize "$TMP/raw_manifest.m3u8")
if printf '%s\n' "$sanitized" | grep -q "#EXT-X-MEDIA-SEQUENCE:123456789"; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: sequence number sanitization failed"
fi

# Test 2: Chunk URL rewriting to absolute edge base
rewritten=$(sh "$MG" rewrite "http://edge.telewebion.net/stream" "$TMP/raw_manifest.m3u8")
if printf '%s\n' "$rewritten" | grep -q "http://edge.telewebion.net/stream/chunk_01.ts" && \
   printf '%s\n' "$rewritten" | grep -q "http://edge.telewebion.net/stream/chunk_02.ts"; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: chunk URL rewriting failed"
fi

# Test 3: Master playlist generator
master=$(ROUTER_IP="192.168.1.1" sh "$MG" master "varzesh")
if printf '%s\n' "$master" | grep -q "http://192.168.1.1/cgi-bin/media/varzesh/480p.m3u8" && \
   printf '%s\n' "$master" | grep -q "http://192.168.1.1/cgi-bin/media/varzesh/720p.m3u8" && \
   printf '%s\n' "$master" | grep -q "http://192.168.1.1/cgi-bin/media/varzesh/1080p.m3u8"; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: master playlist generator failed"
fi

# Test 4: TV status JSON output when standby
tv_json=$(TV_IP="127.0.0.99" sh "$MG" tv status --json)
if printf '%s\n' "$tv_json" | grep -q '"state":"standby"' && \
   printf '%s\n' "$tv_json" | grep -q '"mac":"c8:12:0b:32:7c:f2"'; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: tv status standby json output: $tv_json"
fi

# Test 5: TV status text output when standby
tv_text=$(TV_IP="127.0.0.99" sh "$MG" tv status)
if printf '%s\n' "$tv_text" | grep -q "state=standby" && \
   printf '%s\n' "$tv_text" | grep -q "mac=c8:12:0b:32:7c:f2"; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: tv status standby text output: $tv_text"
fi

# Test 6: CGI stream output headers
cgi_stream=$(REQUEST_METHOD="GET" PATH_INFO="/tamasha.m3u8" sh "$MG" cgi-stream)
if printf '%s\n' "$cgi_stream" | grep -qi "Content-Type: application/vnd.apple.mpegurl" && \
   printf '%s\n' "$cgi_stream" | grep -q "media/tamasha/720p.m3u8"; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: cgi-stream headers / body failed"
fi

# Test 7: TV Wake command
wake_out=$(sh "$MG" tv wake)
if [ "$wake_out" = "wake_packet_sent=c8:12:0b:32:7c:f2" ]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: tv wake failed: $wake_out"
fi

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
