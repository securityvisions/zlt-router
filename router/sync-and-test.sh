#!/bin/sh
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no -o PreferredAuthentications=password -o ConnectTimeout=5 -o LogLevel=ERROR"
AX="192.168.1.1"
PASS="xirouter123"

echo "=== 1. CHECK CLOCK ON VPS ==="
VPS_EPOCH=$(ssh -F /dev/null -i ~/.ssh/id_ed25519_agent -o StrictHostKeyChecking=no root@85.121.124.158 'date -u +%s' 2>/dev/null || date -u +%s)
echo "VPS / Reference Epoch: $VPS_EPOCH ($(date -u -d @$VPS_EPOCH 2>/dev/null || date -u))"

echo ""
echo "=== 2. TEST VPS-REALITY SPEED BEFORE CLOCK SYNC ==="
sshpass -p "$PASS" ssh $SSH_OPTS root@$AX '
    echo -n "Switching proxy-select to vps-reality: "
    curl -s -X PUT -d "{\"name\":\"vps-reality\"}" http://127.0.0.1:9090/proxies/proxy-select
    sleep 1
    echo ""
    echo -n "Download 5MB via vps-reality: "
    curl -sm 10 -x socks5h://127.0.0.1:1080 -o /dev/null -w "%{speed_download} B/s in %{time_total}s (HTTP %{http_code})\n" https://speed.cloudflare.com/__down?bytes=5000000 || echo "FAIL"
'

echo ""
echo "=== 3. SYNC CLOCK ON AX3000T TO REAL TIME ==="
sshpass -p "$PASS" ssh $SSH_OPTS root@$AX "
    date -u -s @$VPS_EPOCH
    echo 'New Router Time: '\$(date -u)
    /etc/init.d/sing-box restart
    sleep 3
"

echo ""
echo "=== 4. RETEST ALL PROXIES AFTER CLOCK SYNC ==="
sshpass -p "$PASS" ssh $SSH_OPTS root@$AX '
    for node in vps-reality vps2-reality hy2 vps2-hy2 via-x28; do
        lat=$(curl -s "http://127.0.0.1:9090/proxies/$node" | grep -o "\"delay\":[0-9]*" || echo "dead")
        echo "  $node: $lat"
    done

    echo ""
    echo "Active Node in proxy-select:"
    curl -s http://127.0.0.1:9090/proxies/proxy-select | grep -o "\"now\":[^,]*"

    echo ""
    echo -n "Download 10MB via vps-reality after clock sync: "
    curl -sm 15 -x socks5h://127.0.0.1:1080 -o /dev/null -w "%{speed_download} B/s (~$(( %{speed_download} * 8 / 1024 / 1024 )) Mbps) in %{time_total}s (HTTP %{http_code})\n" https://speed.cloudflare.com/__down?bytes=10000000 || echo "FAIL"
'
