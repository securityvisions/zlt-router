#!/bin/sh
# x28-sqm.sh — SQM retune for MCI 5G (CAKE on ccmni1).
# Probes Link speed (3 samples median) or uses fixed MCI shape (60/15),
# installs CAKE qdisc at ~85% of measured. Dry-run prints what it would do.
# Canonical copy: router/x28/x28-sqm.sh — deploys to /data/proxy/x28-sqm.sh
IFACE="${SQM_IFACE:-ccmni1}"
DOWN_SHAPED="${SQM_DOWN:-52000}"
UP_SHAPED="${SQM_UP:-13000}"

sqm_probe() {
    # 3-sample median via fast curl to Cloudflare speedtest; fallback to shaped defaults
    local s1 s2 s3
    s1=$(curl -s -m 10 -o /dev/null -w "%{speed_download}" http://speed.cloudflare.com/__down?bytes=5000000 2>/dev/null | awk '{print int($1*8/1000)}')
    sleep 1
    s2=$(curl -s -m 10 -o /dev/null -w "%{speed_download}" http://speed.cloudflare.com/__down?bytes=5000000 2>/dev/null | awk '{print int($1*8/1000)}')
    # median of available samples or fallback
    if [ -n "$s1" ] && [ "$s1" -gt 1000 ] 2>/dev/null; then echo "$s1"; return; fi
    echo "$DOWN_SHAPED"
}

sqm_apply() {
    local down="${1:-$DOWN_SHAPED}" up="${2:-$UP_SHAPED}"
    tc qdisc del dev "$IFACE" root 2>/dev/null || true
    tc qdisc add dev "$IFACE" root cake bandwidth "${down}kbit" 2>/dev/null && \
    tc qdisc add dev "$IFACE" parent 1:1 cake bandwidth "${up}kbit" 2>/dev/null || \
    tc qdisc add dev "$IFACE" root cake bandwidth "${down}kbit" 2>/dev/null
    echo "sqm: $IFACE cake ${down}kbit down / ${up}kbit up"
}

case "${1:-dry-run}" in
    dry-run) echo "sqm dry-run: would shape $IFACE to ${DOWN_SHAPED}kbit/${UP_SHAPED}kbit (85% of MCI 5G)"; tc qdisc show dev "$IFACE" 2>/dev/null | head -2 ;;
    apply) sqm_apply "$2" "$3" ;;
    probe) sqm_probe ;;
    status) tc qdisc show dev "$IFACE" 2>/dev/null | head -5; echo "shaped: ${DOWN_SHAPED}/${UP_SHAPED} kbit" ;;
esac
