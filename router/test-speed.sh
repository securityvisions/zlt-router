#!/bin/sh
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no -o PreferredAuthentications=password -o ConnectTimeout=5 -o LogLevel=ERROR"
AX="192.168.1.1"
PASS="xirouter123"

sshpass -p "$PASS" ssh $SSH_OPTS root@$AX '
    echo "=== CURRENT SPEED BENCHMARK (10MB) ==="
    echo -n "Active Proxy (vps2-hy2): "
    curl -sm 15 -x socks5h://127.0.0.1:1080 -o /dev/null -w "%{speed_download} B/s, total_time=%{time_total}s\n" https://speed.cloudflare.com/__down?bytes=10000000 || echo "FAIL"

    echo -n "Direct Cellular (Bypass): "
    curl -sm 15 -o /dev/null -w "%{speed_download} B/s, total_time=%{time_total}s\n" https://speed.cloudflare.com/__down?bytes=10000000 || echo "FAIL"

    echo ""
    echo "=== ADAPTIVE SQM CURRENT LOGS ==="
    logread | grep -iE "adaptive|sqm|cake" | tail -15 || true
'
