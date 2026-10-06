#!/bin/sh
# detailed-check.sh
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no -o PreferredAuthentications=password -o ConnectTimeout=5 -o LogLevel=ERROR"
AX="192.168.1.1"
PASS="xirouter123"

echo "=== 1. CLOCK COMPARISON (EPOCH) ==="
echo "Host Epoch:    $(date -u +%s)  ($(date -u))"
sshpass -p "$PASS" ssh $SSH_OPTS root@$AX "echo \"Router Epoch:  \$(date -u +%s)  (\$(date -u))\""

echo ""
echo "=== 2. SING-BOX ACTIVE PROXY & NODE DELAYS ==="
sshpass -p "$PASS" ssh $SSH_OPTS root@$AX '
    echo "--- Selected Node in auto ---"
    curl -s http://127.0.0.1:9090/proxies/auto | grep -o "\"now\":[^,]*" || true
    echo "--- Selected Node in proxy-select ---"
    curl -s http://127.0.0.1:9090/proxies/proxy-select | grep -o "\"now\":[^,]*" || true
    echo "--- Selected Node in gaming ---"
    curl -s http://127.0.0.1:9090/proxies/gaming | grep -o "\"now\":[^,]*" || true

    echo ""
    echo "--- Proxy Node Latencies ---"
    for node in vps-reality vps2-reality hy2 vps2-hy2 via-x28; do
        lat=$(curl -s "http://127.0.0.1:9090/proxies/$node" | grep -o "\"delay\":[0-9]*" || echo "dead")
        echo "  $node: $lat"
    done
'

echo ""
echo "=== 3. X28 MODEM CELLULAR LINK STATE (from AX3000T) ==="
sshpass -p "$PASS" ssh $SSH_OPTS root@$AX '
    if [ -f /root/x28link.sh ]; then
        sh /root/x28link.sh
    elif [ -f /usr/sbin/x28link.sh ]; then
        sh /usr/sbin/x28link.sh
    else
        # Try direct curl to X28 web API
        curl -s -m 3 http://192.168.70.1:8080/api/status 2>/dev/null || echo "No x28link helper found"
    fi
'

echo ""
echo "=== 4. SQM CAKE & ADAPTIVE SQM INVESTIGATION ==="
sshpass -p "$PASS" ssh $SSH_OPTS root@$AX '
    echo "--- SQM config ---"
    uci show sqm 2>/dev/null || cat /etc/config/sqm 2>/dev/null || echo "No sqm uci"
    echo ""
    echo "--- Adaptive SQM process ---"
    ps | grep -iE "sqm|adaptive" | grep -v grep || echo "No adaptive sqm running"
    echo ""
    echo "--- Interface drops / errors on lan4 ---"
    ip -s link show lan4
'

echo ""
echo "=== 5. THROUGHPUT BENCHMARK (speed.cloudflare.com) ==="
sshpass -p "$PASS" ssh $SSH_OPTS root@$AX '
    echo "Downloading 10MB test file via SOCKS proxy (vps)..."
    curl -sm 15 -x socks5h://127.0.0.1:1080 -o /dev/null \
      -w "Speed: %{speed_download} bytes/sec (~$(( %{speed_download} * 8 / 1024 / 1024 )) Mbps) | Total Time: %{time_total}s\n" \
      https://speed.cloudflare.com/__down?bytes=10000000 || echo "Proxy download failed or timed out"

    echo "Downloading 10MB test file DIRECT..."
    curl -sm 15 -o /dev/null \
      -w "Speed: %{speed_download} bytes/sec (~$(( %{speed_download} * 8 / 1024 / 1024 )) Mbps) | Total Time: %{time_total}s\n" \
      https://speed.cloudflare.com/__down?bytes=10000000 || echo "Direct download failed or timed out"
'

echo ""
echo "=== 6. TOP BANDWIDTH CONSUMERS (nlbwmon) ==="
sshpass -p "$PASS" ssh $SSH_OPTS root@$AX '
    if which nlbw >/dev/null 2>&1; then
        nlbw -c json -g mac 2>/dev/null | head -n 30 || true
    fi
'
