#!/bin/sh
# cloudflared-setup.sh — expose the Router API remotely via Cloudflare Tunnel.
#
# Canonical copy lives in this repo (router/cloudflared-setup.sh); it runs on
# the AX3000T and requires a Cloudflare account (named tunnel) or a
# trycloudflare quick tunnel (no account, ephemeral). Plain WireGuard is
# unreliable in Iran; cloudflared's HTTPS/HTTP-2 path is harder to block.
#
# Env:
#   CF_TOKEN=<api token>       Cloudflare API token with Tunnel edit rights
#   CF_ACCOUNT=<account id>    Cloudflare account ID
#   CF_TUNNEL=<name>           tunnel name (default "xirouter")
#   CF_DOMAIN=<hostname>       e.g. xirouter.example.com (DNS-managed on CF)
#
# The Router API stays token-gated (HTTP Basic) behind the tunnel; put the
# tunnel behind Cloudflare Access for an extra auth layer if you want.

set -eu

CF_ACCOUNT="${CF_ACCOUNT:?set CF_ACCOUNT}"
CF_TUNNEL="${CF_TUNNEL:-xirouter}"
CF_DOMAIN="${CF_DOMAIN:?set CF_DOMAIN}"
LOCAL_URL="${LOCAL_URL:-http://127.0.0.1:80}"

# Install cloudflared (static binary) if missing.
if ! command -v cloudflared >/dev/null 2>&1; then
    echo "== installing cloudflared =="
    TMP=$(mktemp -d)
    cd "$TMP"
    curl -sSL -o cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 2>/dev/null
    chmod +x cloudflared
    mv cloudflared /usr/bin/cloudflared
    cd /
    rm -rf "$TMP"
fi

echo "== login / create tunnel =="
cloudflared tunnel login 2>&1 || true
cloudflared tunnel create "$CF_TUNNEL" 2>&1 || true

echo "== route DNS =="
cloudflared tunnel route dns "$CF_TUNNEL" "$CF_DOMAIN" 2>&1 || true

echo "== write config =="
mkdir -p /etc/cloudflared
cat > /etc/cloudflared/config.yml <<EOF
tunnel: $CF_TUNNEL
credentials-file: /root/.cloudflared/$CF_TUNNEL.json
ingress:
  - hostname: $CF_DOMAIN
    service: $LOCAL_URL
  - service: http_status:404
EOF

echo "== run (procd) =="
cat > /etc/init.d/cloudflared <<'EOF'
#!/bin/sh /etc/rc.common
USE_PROCD=1
START=95
STOP=15
start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/cloudflared
    procd_append_param command tunnel
    procd_append_param command --config /etc/cloudflared/config.yml
    procd_append_param command run
    procd_set_param respawn 3600 5 5
    procd_close_instance
}
EOF
chmod +x /etc/init.d/cloudflared
/etc/init.d/cloudflared enable
/etc/init.d/cloudflared start

echo "tunnel up: https://$CF_DOMAIN -> $LOCAL_URL (Router API is token-gated)"
