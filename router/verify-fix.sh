#!/bin/sh
SSH_OPTS="-F /dev/null -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no -o PreferredAuthentications=password"
AX="192.168.1.1"
PASS="xirouter123"

sshpass -p "$PASS" ssh $SSH_OPTS root@$AX '
    echo "=== ACTIVE NODE IN PROXY-SELECT ==="
    curl -s http://127.0.0.1:9090/proxies/proxy-select | grep -o "\"now\":[^,]*"

    echo ""
    echo "=== NODE DELAYS ==="
    for n in vps-reality vps2-reality hy2 vps2-hy2 via-x28; do
        d=$(curl -s "http://127.0.0.1:9090/proxies/$n" | grep -o "\"delay\":[0-9]*" || echo "dead")
        echo "  $n: $d"
    done

    echo ""
    echo "=== DOWNLOAD 10MB SPEED TEST ==="
    curl -sm 15 -x socks5h://127.0.0.1:1080 -o /dev/null \
      -w "Speed: %{speed_download} Bytes/sec | Time: %{time_total}s | HTTP: %{http_code}\n" \
      https://speed.cloudflare.com/__down?bytes=10000000 || echo "FAIL"

    echo ""
    echo "=== WATCHDOG STATE ==="
    cat /tmp/proxy-watchdog.state 2>/dev/null || echo "No watchdog state"
'
