#!/bin/sh
# Telegram alert helper — shared library + CLI (chat-beauty-v2 #06: card restyle)
. /etc/tg.conf 2>/dev/null || { echo "tg.conf missing" >&2; exit 1; }
. /root/botlib.sh 2>/dev/null || { echo "botlib.sh missing" >&2; exit 1; }
. /root/hnlib.sh 2>/dev/null || { echo "hnlib.sh missing" >&2; exit 1; }

MAXMSG="${MAXMSG:-4000}"

split_chunks() {
    printf '%s\n' "${1:-}" | awk -v max="${MAXMSG:-4000}" '
    BEGIN { if (max !~ /^[0-9]+$/ || max == 0) max = 4000 }
    {
        line = $0 "\n"
        while (length(line) > max) { print substr(line, 1, max); line = substr(line, max+1) }
        if (length(buf) + length(line) > max) { printf "%s", buf; buf = "" }
        buf = buf line
    }
    END { sub(/\n$/, "", buf); printf "%s", buf }'
}

join_chunks() {
    _jf=$(mktemp 2>/dev/null) || return 0
    split_chunks "${1:-}" > "$_jf"
    awk -v max="${MAXMSG:-4000}" -v sep="[[C]]" '
    {
        piece = $0 "\n"
        if (length(buf) > 0 && length(buf) + length(piece) > max) { printf "%s%s", buf, sep; buf = "" }
        buf = buf piece
    }
    END { sub(/\n$/, "", buf); printf "%s", buf }' "$_jf"
    rm -f "$_jf"
}

tg_send_one() {
    local text="$1" proxy_arg="" resp ok
    [ -z "$text" ] && return 0
    if [ -n "${TG_PROXY:-}" ]; then
        proxy_arg="-x $TG_PROXY"
    elif nc -z -w 1 127.0.0.1 1080 >/dev/null 2>&1; then
        proxy_arg="-x socks5h://127.0.0.1:1080"
    elif nc -z -w 1 192.168.70.1 1080 >/dev/null 2>&1; then
        proxy_arg="-x socks5h://192.168.70.1:1080"
    fi
    resp=$(curl -s -m 12 $proxy_arg "https://api.telegram.org/bot$TOKEN/sendMessage" \
        --data-urlencode "chat_id=$CHAT_ID" \
        --data-urlencode "parse_mode=HTML" \
        --data-urlencode 'link_preview_options={"is_disabled":true}' \
        --data-urlencode "text=$text" 2>&1)
    if [ -n "$resp" ]; then
        echo "$resp" >> /tmp/tg.log 2>&1
        ok=$(printf '%s' "$resp" | jq -r '.ok // "false"' 2>/dev/null || true)
        if [ "$ok" != "true" ] && [ -n "$ok" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') tg_send failed: $resp" >> /tmp/tg-error.log 2>&1 || true
        fi
    fi
}

tg_send() {
    local text="$1" rest part
    [ -z "$text" ] && return 0
    if [ "${#text}" -le "${MAXMSG:-4000}" ]; then
        tg_send_one "$text"
        return
    fi
    rest=$(join_chunks "$text")
    while [ -n "$rest" ]; do
        case "$rest" in
            *"[[C]]"*) part=${rest%%"[[C]]"*}; rest=${rest#*"[[C]]"} ;;
            *)         part=$rest;             rest="" ;;
        esac
        [ -n "$part" ] && tg_send_one "$part"
    done
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