#!/bin/sh
echo "=== 1. RESTARTING S-UI ON VPS 1 ==="
ssh -F /dev/null -i ~/.ssh/id_ed25519_agent -o StrictHostKeyChecking=no root@85.121.124.158 '
    systemctl restart sui
    sleep 2
    systemctl is-active sui
    uptime
'

echo ""
echo "=== 2. CHECKING VPS 2 S-UI & PORT 443 ==="
ssh -F /dev/null -i ~/.ssh/id_ed25519_agent -o StrictHostKeyChecking=no root@5.175.234.113 '
    systemctl is-active sui || systemctl is-active s-ui
    ss -tulpn | grep -E ":443|:31800"
'

echo ""
echo "=== 3. BENCHMARK AX3000T PROXY NODES ==="
sshpass -p "xirouter123" ssh -F /dev/null -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no -o PreferredAuthentications=password root@192.168.1.1 '
    echo "--- Switch to vps-reality ---"
    curl -s -X PUT -d "{\"name\":\"vps-reality\"}" http://127.0.0.1:9090/proxies/proxy-select
    sleep 2

    echo "--- Delays ---"
    for n in vps-reality vps2-reality hy2 vps2-hy2; do
        echo -n "  $n: "
        curl -s "http://127.0.0.1:9090/proxies/$n" | grep -o "\"delay\":[0-9]*" || echo "dead"
    done

    echo "--- Speedtest 10MB through vps-reality ---"
    curl -sm 15 -x socks5h://127.0.0.1:1080 -o /dev/null \
      -w "Speed: %{speed_download} Bytes/sec | Time: %{time_total}s | HTTP %{http_code}\n" \
      https://speed.cloudflare.com/__down?bytes=10000000 || echo "FAIL"
'
