#!/bin/sh
# wan-detector.sh — Auto-sense which physical port connects to X28 (192.168.70.1)
# Physical ports on Xiaomi AX3000T DSA: wan (port 1), lan2 (port 2), lan3 (port 3), lan4 (port 4)

X28_IP="192.168.70.1"
X28_MAC="98:a9:42:6b:67:b8"
CANDIDATES="wan lan2 lan3 lan4"
LOG_TAG="wan-detector"

detect_uplink() {
    for p in $CANDIDATES; do
        carrier=$(cat "/sys/class/net/$p/carrier" 2>/dev/null || echo 0)
        [ "$carrier" = "1" ] || continue
        
        # Probe X28 at Layer 2
        if arping -I "$p" -c 1 -w 1 "$X28_IP" 2>/dev/null | grep -qi "$X28_MAC"; then
            echo "$p"
            return 0
        fi
    done
    return 1
}

apply_port_mapping() {
    new_wan="$1"
    curr_wan=$(uci -q get network.wan.device || echo "")
    [ "$new_wan" = "$curr_wan" ] && return 0

    logger -t "$LOG_TAG" "X28 detected on port $new_wan (was: $curr_wan). Reconfiguring..."

    # Configure the other 3 ports for br-lan
    uci set network.wan.device="$new_wan"
    uci -q delete network.@device[0].ports
    for p in $CANDIDATES; do
        [ "$p" = "$new_wan" ] && continue
        uci add_list network.@device[0].ports="$p"
    done
    uci commit network

    # Reload network stack via ubus seamlessly
    ubus call network reload
    logger -t "$LOG_TAG" "Port $new_wan is now WAN; remaining ports bridged into br-lan."
}

logger -t "$LOG_TAG" "Starting auto-sensing WAN port detector daemon..."

while :; do
    uplink=$(detect_uplink || true)
    if [ -n "$uplink" ]; then
        apply_port_mapping "$uplink"
        sleep 10
    else
        # When X28 is booting or offline, wait patiently
        sleep 5
    fi
done
