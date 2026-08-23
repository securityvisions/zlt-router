#!/bin/sh
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo ""

# Whitelist of services safe to check/restart
# NEVER includes: networking, dnsmasq, firewall, dropbear, mini_httpd
SERVICES="mihomo:x28proxy operator-watchdog:x28-watchdog bot:x28-bot usage-collector:x28-usage adblock:x28-adblock thermal:x28-thermal rescue:x28-rescue drift:x28-drift dash-data:x28-dash-data"

echo '{"services":['
first=1
for pair in $SERVICES; do
    label="${pair%%:*}"
    svc="${pair##*:}"
    if [ -x "/etc/init.d/$svc" ]; then
        if "/etc/init.d/$svc" running 2>/dev/null || pgrep -f "$svc" >/dev/null 2>&1; then
            status="running"
        else
            status="stopped"
        fi
    else
        status="not-installed"
    fi
    [ "$first" = "0" ] && echo ","
    printf '{"name":"%s","status":"%s"}' "$label" "$status"
    first=0
done
echo ']}'
