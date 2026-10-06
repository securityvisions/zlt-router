#!/bin/bash
# quick-diag.sh — Rapid diagnostics for home network slowness


SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no -o PreferredAuthentications=password -o ConnectTimeout=5 -o LogLevel=ERROR"
AX_IP="192.168.1.1"
AX_PASS="xirouter123"
X28_IP="192.168.70.1"
X28_PASS="G5K0utrzATYX"

echo "=========================================="
echo ">>> 1. HOST & DIRECT NETWORK CHECK"
echo "=========================================="
HOST_EPOCH=$(date -u +%s)
echo "Host Time (UTC): $(date -u)"
ip route show default || true

echo ""
echo "=========================================="
echo ">>> 2. AX3000T ROUTER (192.168.1.1) STATUS"
echo "=========================================="
if ! ping -c 1 -W 2 "$AX_IP" >/dev/null 2>&1; then
    echo "[!] Cannot ping AX3000T at $AX_IP"
else
    echo "[+] AX3000T is reachable via ICMP"
    sshpass -p "$AX_PASS" ssh $SSH_OPTS root@"$AX_IP" bash -c '
        echo "--- Router Time & Skew ---"
        ROUTER_EPOCH=$(date -u +%s)
        echo "Router Time: $(date -u)"
        echo "Uptime & Load: $(uptime)"
        echo "Memory: $(free -m | grep Mem | awk '\''{print "used="$3"MB, free="$4"MB, total="$2"MB"}'\'')"

        echo ""
        echo "--- Sing-Box & Proxy Watchdog State ---"
        if [ -f /tmp/proxy-watchdog.state ]; then
            echo "Watchdog State: $(cat /tmp/proxy-watchdog.state)"
        else
            echo "Watchdog State: (no state file)"
        fi

        echo -n "nftables axproxy table: "
        if nft list table inet axproxy >/dev/null 2>&1; then
            echo "ACTIVE"
        else
            echo "FLUSHED / INACTIVE (Fail-Open active!)"
        fi

        echo ""
        echo "--- Clash API Node Status ---"
        if curl -s -m 2 http://127.0.0.1:9090/proxies/proxy-select >/dev/null 2>&1; then
            ACTIVE_NODE=$(curl -s http://127.0.0.1:9090/proxies/proxy-select | grep -o "\"now\":[^,]*")
            echo "Active Node: $ACTIVE_NODE"
        else
            echo "Clash API: Not responding on 9090"
        fi

        echo ""
        echo "--- Proxy Latency & Connectivity ---"
        echo -n "SOCKS5 Proxy (Google 204): "
        curl -sm 6 -x socks5h://127.0.0.1:1080 -o /dev/null -w "HTTP %{http_code} | Total: %{time_total}s | Connect: %{time_connect}s\n" http://www.gstatic.com/generate_204 || echo "FAILED/TIMEOUT"

        echo -n "Direct Internet (Google 204): "
        curl -sm 6 -o /dev/null -w "HTTP %{http_code} | Total: %{time_total}s | Connect: %{time_connect}s\n" http://connectivitycheck.gstatic.com/generate_204 || echo "FAILED/TIMEOUT"

        echo ""
        echo "--- DNS Latency Test ---"
        echo -n "LAN DNS (127.0.0.1:53 dnsmasq): "
        nslookup -timeout=3 google.com 127.0.0.1 >/dev/null 2>&1 && echo "OK" || echo "FAIL/TIMEOUT"
        echo -n "Sing-box DNS (127.0.0.1:5354 DoH): "
        nslookup -timeout=3 -port=5354 google.com 127.0.0.1 >/dev/null 2>&1 && echo "OK" || echo "FAIL/TIMEOUT"

        echo ""
        echo "--- Active WAN & SQM State ---"
        WAN_IF=$(ubus call network.interface.wan status 2>/dev/null | grep -o "\"l3_device\": \"[^\"]*\"" | cut -d"\"" -f4)
        echo "Active WAN interface: $WAN_IF"
        tc -s qdisc show dev ${WAN_IF:-lan4} 2>/dev/null | grep -E "qdisc cake|Sent|backlog" || true

        echo ""
        echo "--- Ping to VPS (85.121.124.158) ---"
        ping -c 4 -W 2 85.121.124.158 | tail -2 || true

        echo ""
        echo "--- Top Current Connections / Bandwidth ---"
        cat /proc/net/nf_conntrack 2>/dev/null | wc -l | awk '\''{print "Active conntrack sessions: "$1}'\''
    ' 2>&1 || echo "[!] SSH to AX3000T failed"
fi

echo ""
echo "=========================================="
echo ">>> 3. X28 CELLULAR MODEM (192.168.70.1) STATUS"
echo "=========================================="
if ! ping -c 1 -W 2 "$X28_IP" >/dev/null 2>&1; then
    echo "[!] Cannot ping X28 at $X28_IP directly from host"
fi

sshpass -p "$AX_PASS" ssh $SSH_OPTS root@"$AX_IP" bash -c "
    sshpass -p '$X28_PASS' ssh $SSH_OPTS -o HostKeyAlgorithms=+ssh-rsa root@'$X28_IP' '
        echo \"--- X28 Link State ---\"
        if [ -x /data/proxy/linkstate.sh ]; then
            /data/proxy/linkstate.sh
        else
            cat /proc/uptime
        fi
        echo \"Load & Mem: \$(uptime)\"
        echo \"Ping to 8.8.8.8:\"; ping -c 3 8.8.8.8 | tail -2
    ' 2>&1
" || echo "[!] Could not query X28 via AX3000T"

echo ""
echo "=========================================="
echo ">>> DIAGNOSTICS COMPLETE"
echo "=========================================="
