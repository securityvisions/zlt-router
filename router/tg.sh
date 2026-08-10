#!/bin/sh
# Telegram alert helper — shared library + CLI (chat-beauty-v2 #06: card restyle)
. /etc/tg.conf 2>/dev/null || { echo "tg.conf missing" >&2; exit 1; }
. /root/botlib.sh 2>/dev/null || { echo "botlib.sh missing" >&2; exit 1; }

tg_send() {
    local text="$1"
    [ -z "$text" ] && return 0
    curl -s -m 8 "https://api.telegram.org/bot$TOKEN/sendMessage" \
        --data-urlencode "chat_id=$CHAT_ID" \
        --data-urlencode "parse_mode=HTML" \
        --data-urlencode "text=$text" >> /tmp/tg.log 2>&1 || true
}

tg_card() {  # tg_card <title> <body>  — send an alert Card (alert_text + tg_send)
    local text
    text=$(alert_text "$1" "$2")
    tg_send "$text"
}

case "$1" in
    --card)
        shift; tg_card "$1" "$2"
        ;;
    --disk)
        set -- $(df -h / | awk 'NR==2')
        avail="$4"; pct="$5"
        n=${pct%\%}
        if [ "$n" -gt 85 ] 2>/dev/null; then
            tg_card "⚠️ Storage high" "${pct} used (${avail} free)"
        fi
        ;;
    --reboot)
        load=$(awk '{print $1}' /proc/loadavg)
        up=$(uptime | sed 's/.*up \([^,]*\),.*/\1/')
        temp=$(awk '{print int($1/1000)}' /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        tg_card "🔄 Router back online" "uptime ${up} · load ${load} · temp ${temp}°C"
        ;;
    *)
        [ -n "$1" ] && tg_send "$1"
        ;;
esac