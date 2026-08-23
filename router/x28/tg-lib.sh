#!/bin/sh
# tg-lib.sh — Telegram transport module.
#
# Owns ALL Telegram API knowledge: HTTP transport via SOCKS proxy, HTML
# parse_mode, chunk budget (4096 API limit), link-preview suppression,
# response-aware logging. Zero knowledge of commands or router state.
#
# Callers source this file and provide:
#   CHAT_ID   — allowlisted chat ID
#   TOKEN     — bot token
#   PROXY     — socks5h://… proxy URL (optional; default X28 crypto engine)
#   JQ        — path to jq binary
#   LOGF      — log file path
#
# Exports:
#   esc(s)                    — HTML-escape & < >
#   split_chunks(text)        — ≤MAXMSG-char pieces at newline boundaries
#   join_chunks(text)         — pieces joined by "[[C]]" sentinel
#   tg_post(method, args…)    — raw API call + response-aware logging
#   send_one(html)            — exactly one sendMessage call
#   html_send(html)           — chunked sendMessage
#   edit_html(mid, html)      — editMessageText with fallback to send
#   send_photo(path, caption) — multipart photo upload
#   answer_cbq(id, [text])    — acknowledge callback query
#
# Env seams for tests: MAXMSG=4000, TG_LOG (caller's log fn), DRYRUN=1.

MAXMSG="${MAXMSG:-4000}"

esc() { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

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
    awk -v max="$MAXMSG" -v sep="[[C]]" '
    {
        piece = $0 "\n"
        if (length(buf) > 0 && length(buf) + length(piece) > max) { printf "%s%s", buf, sep; buf = "" }
        buf = buf piece
    }
    END { sub(/\n$/, "", buf); printf "%s", buf }' "$_jf"
    rm -f "$_jf"
}

verdict_emoji() {
    case "$1" in
        *GREEN*) echo "✅ $1" ;;
        *RED*)   echo "❌ $1" ;;
        *)       echo "⚠️ ${1:-unknown}" ;;
    esac
}

safe_arg() {
    case "${1:-}" in "") return 1 ;; *[!A-Za-z0-9_.:-]*) return 1 ;; esac
    printf '%s' "$1"
}

now_hm() { date '+%H:%M' 2>/dev/null; }

tg_log() {
    if [ -n "${TG_LOG_FN:-}" ]; then
        "$TG_LOG_FN" "$@"
    elif [ -n "${LOGF:-}" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOGF"
    fi
}

tg_post() {
    _m="$1"; shift
    [ -n "${API:-}" ] || return 0
    _resp=$(timeout 20 curl -s -m 18 -x "$PROXY" "$API/$_m" "$@" 2>/dev/null)
    if [ -n "${JQ:-}" ] && [ -x "$JQ" ]; then
        _ok=$(printf '%s' "$_resp" | "$JQ" -r '.ok // "false"' 2>/dev/null)
        if [ "$_ok" != "true" ]; then
            _code=$(printf '%s' "$_resp" | "$JQ" -r '.error_code // "-"' 2>/dev/null)
            _desc=$(printf '%s' "$_resp" | "$JQ" -r '.description // "empty response"' 2>/dev/null)
            tg_log "tg: $_m FAILED ($_code) $_desc"
        fi
    fi
    printf '%s' "$_resp"
}

send_one() {
    tg_post sendMessage \
        --data-urlencode "chat_id=${CHAT_ID:-}" \
        --data-urlencode "text=$1" \
        --data-urlencode "parse_mode=HTML" \
        --data-urlencode 'link_preview_options={"is_disabled":true}' >/dev/null 2>&1 || true
}

html_send() {
    rest=$(join_chunks "${1:-}")
    while [ -n "$rest" ]; do
        case "$rest" in
            *"[[C]]"*) part=${rest%%"[[C]]"*}; rest=${rest#*"[[C]]"} ;;
            *)         part=$rest;             rest="" ;;
        esac
        [ -n "$part" ] && send_one "$part"
    done
}

edit_html() {
    _mid="$1"
    rest=$(join_chunks "$2")
    while [ -n "$rest" ]; do
        case "$rest" in
            *"[[C]]"*) part=${rest%%"[[C]]"*}; rest=${rest#*"[[C]]"} ;;
            *)         part=$rest;             rest="" ;;
        esac
        [ -n "$part" ] || continue
        _resp=$(tg_post editMessageText \
            --data-urlencode "chat_id=${CHAT_ID:-}" \
            --data-urlencode "message_id=$_mid" \
            --data-urlencode "text=$part" \
            --data-urlencode "parse_mode=HTML" \
            --data-urlencode 'link_preview_options={"is_disabled":true}')
        _ok=$(printf '%s' "$_resp" | "${JQ:-jq}" -r '.ok // "false"' 2>/dev/null)
        if [ "$_ok" != "true" ]; then
            _desc=$(printf '%s' "$_resp" | "${JQ:-jq}" -r '.description // ""' 2>/dev/null)
            case "$_desc" in *"not modified"*) : ;; *) html_send "$part" ;; esac
        fi
    done
}

answer_cbq() {
    [ -n "${API:-}" ] || return 0
    timeout 10 curl -s -m 8 -x "$PROXY" "$API/answerCallbackQuery" \
        --data-urlencode "callback_query_id=${1:-}" \
        ${2:+--data-urlencode "text=$2"} >/dev/null 2>&1 || true
}

send_photo() {
    [ -f "${1:-}" ] || return 1
    timeout 30 curl -s -m 25 -x "$PROXY" "$API/sendPhoto" \
        -F "chat_id=${CHAT_ID:-}" -F "photo=@$1" -F "caption=${2:-}" \
        -F "parse_mode=HTML" >/dev/null 2>&1 || true
}
