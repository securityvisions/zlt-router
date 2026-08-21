#!/bin/sh
# tg-notify.sh — send a Telegram card from the X28 (alerts path).
# Best-effort by design: NEVER blocks or crashes a caller. Any failure
# (no config, proxy down, API down) exits 0 silently — the event is
# already in the caller's log; the alert is a bonus.
#
# Canonical copy: router/x28/tg-notify.sh — deploys to /data/proxy/tg-notify.sh.
# Config: /etc/tg.conf (root-only): TOKEN=... CHAT_ID=...
#   CHAT_ID empty/placeholder -> silent no-op (alerting not provisioned yet).
# Route: via the box's own crypto engine (SOCKS 192.168.70.1:1080 -> VPS),
# which also solves DNS (socks5h resolves at the exit).

CONF=/etc/tg.conf
[ -r "$CONF" ] || exit 0
. "$CONF" 2>/dev/null || exit 0
[ -n "${TOKEN:-}" ] || exit 0
case "${CHAT_ID:-}" in ""|__*|0) exit 0 ;; esac

title="${1:-X28}"
body="${2:-}"

timeout 20 curl -s -m 18 -x socks5h://192.168.70.1:1080 \
    "https://api.telegram.org/bot$TOKEN/sendMessage" \
    --data-urlencode "chat_id=$CHAT_ID" \
    --data-urlencode "text=$title
──────────────
$body" >/dev/null 2>&1 || true
exit 0
