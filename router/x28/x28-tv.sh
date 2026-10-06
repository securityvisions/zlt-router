#!/bin/sh
# x28-tv.sh — Samsung Q70C TV integration helper
# TV IP: 192.168.1.105, MAC: c8:12:0b:32:7c:f2
TV_IP="${TV_IP:-192.168.1.105}"
TV_MAC="${TV_MAC:-c8:12:0b:32:7c:f2}"

tv_status() {
    local info
    info=$(curl -sk -m 2 "http://$TV_IP:8001/api/v2/" 2>/dev/null)
    if [ -n "$info" ]; then
        local name model os
        name=$(printf '%s' "$info" | jq -r '.device.name // "Samsung Q70C"' 2>/dev/null)
        model=$(printf '%s' "$info" | jq -r '.device.modelName // "Q70C"' 2>/dev/null)
        os=$(printf '%s' "$info" | jq -r '.device.OS // "Tizen"' 2>/dev/null)
        printf '📺 <b>%s</b> (%s)\n• Power: 🟢 <b>ON</b>\n• IP: <code>%s</code>\n• OS: %s\n• IPTV: <code>http://192.168.1.1/cgi-bin/tv.m3u8</code>' "$name" "$model" "$TV_IP" "$os"
    else
        if ping -c 1 -W 1 "$TV_IP" >/dev/null 2>&1; then
            printf '📺 <b>Samsung Q70C</b>\n• Power: 🟡 <b>STANDBY / NETWORK ACTIVE</b>\n• IP: <code>%s</code>\n• MAC: <code>%s</code>' "$TV_IP" "$TV_MAC"
        else
            printf '📺 <b>Samsung Q70C</b>\n• Power: 🔴 <b>OFF / DEEP SLEEP</b>\n• IP: <code>%s</code>\n• MAC: <code>%s</code>\n• <i>Send /tv on to wake via WOL</i>' "$TV_IP" "$TV_MAC"
        fi
    fi
}

tv_wake() {
    # Send WOL magic packet via AX3000T etherwake on br-lan
    sshpass -p "xirouter123" ssh -o StrictHostKeyChecking=no root@192.168.1.1 "/usr/bin/etherwake -b -i br-lan $TV_MAC" 2>/dev/null || true
    echo "⚡ Magic packet (WOL) sent to $TV_MAC"
}

case "${1:-status}" in
    status) tv_status ;;
    on|wake) tv_wake ;;
    *) echo "usage: x28-tv.sh [status|on|wake]" ;;
esac
