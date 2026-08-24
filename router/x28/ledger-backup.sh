#!/bin/sh
# ledger-backup.sh — weekly off-router backup of the Ledger history.
#
# Tars owners-d/ + rollups/ + billing.conf (a few hundred KB today, ~1MB/year)
# and sends the archive as a Telegram document to the owner's chat, so a flash
# failure can never eat the household Ledger. Best-effort: any failure exits
# non-zero quietly without crashing the caller (the usage-collect roll loop).
#
# Modes:
#   run      — build + send at most once per ISO week (marker)
#   dry-run  — build + describe; no send, no marker
#   build    — build only; prints the archive path
#
# Env seams for tests: USAGE_DIR, WEEK, SEND_CMD, TG_LIB.
# Canonical copy: router/x28/ledger-backup.sh — deploys to /data/proxy/ledger-backup.sh.

USAGE_DIR="${USAGE_DIR:-/data/proxy/usage}"
TG_LIB="${TG_LIB:-/data/proxy/tg-lib.sh}"

build_archive() {
    _bd="$USAGE_DIR/backups"
    mkdir -p "$_bd" 2>/dev/null || return 1
    _arc="$_bd/ledger-$(date +%Y%m%d).tar.gz"
    tar -czf "$_arc" -C "$USAGE_DIR" owners-d rollups billing.conf 2>/dev/null || return 1
    # bound disk: keep the newest 4 archives
    ls -1t "$_bd"/ledger-*.tar.gz 2>/dev/null | tail -n +5 | xargs rm -f 2>/dev/null
    printf '%s' "$_arc"
}

default_send() {
    [ -r /etc/tg.conf ] || return 1
    . /etc/tg.conf 2>/dev/null || return 1
    [ -n "${TOKEN:-}" ] || return 1
    case "${CHAT_ID:-}" in ""|__*|0) return 1 ;; esac
    API="https://api.telegram.org/bot$TOKEN"
    PROXY="socks5h://192.168.70.1:1080"
    export CHAT_ID
    [ -f "$TG_LIB" ] && . "$TG_LIB"
    command -v send_document >/dev/null 2>&1 || return 1
    send_document "$1" "📒 Ledger backup · $(date +%F) · week ${WEEK:-$(date +%G-W%V)}"
}

send_archive() {
    if [ -n "${SEND_CMD:-}" ]; then
        sh -c "$SEND_CMD" ledger-backup "$1"
    else
        default_send "$1"
    fi
}

week="${WEEK:-$(date +%G-W%V)}"
marker="$USAGE_DIR/.ledger-backup-week"

case "${1:-run}" in
    build)
        arc=$(build_archive) || exit 1
        printf '%s\n' "$arc" ;;
    dry-run)
        arc=$(build_archive) || { echo "archive build failed"; exit 1; }
        echo "dry-run: would send $arc ($(du -h "$arc" 2>/dev/null | cut -f1)) for week $week"
        tar -tzf "$arc" 2>/dev/null | head -5
        ;;
    run)
        [ "$(cat "$marker" 2>/dev/null)" = "$week" ] && exit 0
        arc=$(build_archive) || exit 1
        if send_archive "$arc"; then
            echo "$week" > "$marker" 2>/dev/null
        fi
        ;;
    *)
        echo "usage: ledger-backup.sh [run|dry-run|build]" >&2; exit 2 ;;
esac
