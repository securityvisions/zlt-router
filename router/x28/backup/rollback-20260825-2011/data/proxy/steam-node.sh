#!/bin/sh
# steam-node.sh — pin Steam voice to a chosen proxy node.
#
# Steam voice flows through the engine's tun (steam-tun-enable.sh) and the
# steam-voice rule-set decides the node. This switches the pinned node in the
# engine config and hot-reloads it; with no arguments it reports the current
# pin. Validates the node exists in the config (proxy or group member).
#
# Env seams for tests: STEAM_CONFIG, MIHOMO_CTRL, JQ_BIN.
# Canonical copy: router/x28/steam-node.sh — deploys to /data/proxy/steam-node.sh.

CFG="${STEAM_CONFIG:-/data/proxy/mihomo/config.yaml}"
CTRL="${MIHOMO_CTRL:-http://127.0.0.1:9090}"
JQ="${JQ_BIN:-/data/proxy/jq}"

steam_current_node() {
    sed -n 's/.*RULE-SET,steam-voice,\([^,]*\).*/\1/p' "$CFG" 2>/dev/null | head -1
}

steam_valid_node() {
    grep -qE "^  - name: $1$|^      - $1$" "$CFG" 2>/dev/null
}

steam_swap_node() {
    sed -i "s/RULE-SET,steam-voice,[^,]*/RULE-SET,steam-voice,$1/" "$CFG" 2>/dev/null
}

steam_reload() {
    if [ -n "${STEAM_CONFIG:-}" ]; then
        return 0   # tests: no live controller
    fi
    curl -s -m 10 -X PUT "$CTRL/configs?force=true" \
        -d "{\"path\":\"$CFG\"}" >/dev/null 2>&1 || \
        /etc/init.d/x28proxy restart >/dev/null 2>&1
}

case "${1:-show}" in
    show) steam_current_node ;;
    *)
        if steam_valid_node "$1"; then
            steam_swap_node "$1"
            steam_reload
            echo "Steam voice pinned to $1"
        else
            echo "unknown node: $1" >&2
            exit 1
        fi ;;
esac