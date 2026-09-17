#!/bin/sh
# Telegram alert helper — shared library + CLI (chat-beauty-v2 #06: card restyle)
. /etc/tg.conf 2>/dev/null || { echo "tg.conf missing" >&2; exit 1; }
. /root/botlib.sh 2>/dev/null || { echo "botlib.sh missing" >&2; exit 1; }
. /root/hnlib.sh 2>/dev/null || { echo "hnlib.sh missing" >&2; exit 1; }

tg_send() {
    local text="$1" proxy_arg=""
    [ -z "$text" ] && return 0
    if [ -n "${TG_PROXY:-}" ]; then
        proxy_arg="-x $TG_PROXY"
    elif nc -z -w 1 127.0.0.1 1080 >/dev/null 2>&1; then
        proxy_arg="-x socks5h://127.0.0.1:1080"
    elif nc -z -w 1 192.168.70.1 1080 >/dev/null 2>&1; then
        proxy_arg="-x socks5h://192.168.70.1:1080"
    fi
    curl -s -m 12 $proxy_arg "https://api.telegram.org/bot$TOKEN/sendMessage" \
        --data-urlencode "chat_id=$CHAT_ID" \
        --data-urlencode "parse_mode=HTML" \
        --data-urlencode 'link_preview_options={"is_disabled":true}' \
        --data-urlencode "text=$text" >> /tmp/tg.log 2>&1 || true
}

tg_card() {  # tg_card <title> <body>  — send an alert Card (alert_text + tg_send)
    local text
    text=$(alert_text "$(esc "$1")" "$(esc "$2")")
    tg_send "$text"
}

case "$1" in
    --card)
        shift; tg_card "$1" "$2"
        ;;
    --disk)
        set -- $(hn_sys_disk)
        avail="$2"; pct="$1"
        if [ "$pct" -gt 85 ] 2>/dev/null; then
            tg_card "⚠️ Storage high" "${pct}% used (${avail} free)"
        fi
        ;;
    --reboot)
        load=$(hn_sys_load)
        up=$(hn_sys_uptime)
        temp=$(hn_sys_temp_c)
        tg_card "🔄 Router back online" "uptime ${up} · load ${load} · temp ${temp}°C"
        ;;
    *)
        [ -n "$1" ] && tg_send "$1"
        ;;
esac