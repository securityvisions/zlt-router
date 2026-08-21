#!/bin/sh
# x28-tunnel.sh — Cloudflare Tunnel setup helper for remote access.
# Usage: x28-tunnel.sh setup <token>  — stores token in /etc/tunnel.conf (600) and restarts service.
#        x28-tunnel.sh status          — checks tunnel health.
# Binary lives at /data/proxy/cloudflared (downloaded on first setup).
# No firewall hole is opened — Tunnel is outbound-only.
# Canonical copy: router/x28/x28-tunnel.sh — deploys to /data/proxy/x28-tunnel.sh
CONF=/etc/tunnel.conf
BIN=/data/proxy/cloudflared

tunnel_setup() {
    local token="$1"
    [ -z "$token" ] && { echo "usage: x28-tunnel.sh setup <token>"; return 1; }
    mkdir -p /data/proxy
    if [ ! -x "$BIN" ]; then
        echo "downloading cloudflared..."
        curl -sL -m 60 -o "$BIN" "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64" 2>/dev/null || return 1
        chmod +x "$BIN"
    fi
    printf '%s\n' "$token" > "$CONF" && chmod 600 "$CONF"
    /etc/init.d/x28-tunnel restart 2>/dev/null || /etc/init.d/x28-tunnel start 2>/dev/null
    echo "tunnel: configured and restarted"
}

tunnel_status() {
    if [ -f "$CONF" ]; then echo "tunnel: configured ($(wc -c < "$CONF" | tr -d ' ')B token)"; else echo "tunnel: not configured (run x28-tunnel.sh setup <token>)"; fi
    pgrep -x cloudflared >/dev/null 2>&1 && echo "cloudflared: running" || echo "cloudflared: not running (token needed)"
    if pgrep -x cloudflared >/dev/null 2>&1; then
        # health via telemetry
        tail -1 /data/proxy/usage/telemetry.log 2>/dev/null | grep -q . && echo "telemetry: ok" || echo "telemetry: pending"
    fi
}

case "${1:-status}" in
    setup) tunnel_setup "$2" ;;
    status) tunnel_status ;;
    *) echo "usage: x28-tunnel.sh {setup <token>|status}" ;;
esac
