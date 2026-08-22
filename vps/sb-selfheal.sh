#!/bin/sh
# sb-selfheal.sh — workstation-vantage VPS core self-heal (Ticket: x28-always-up/06).
# Independent of the X28: probes the FULL tunnel end-to-end from this host
# (SOCKS on the X28 -> Reality -> internet). After N consecutive dead minutes
# with the panel reachable, logs in and POSTs restartSb — the same proven
# action x28-vps-heal uses, but from a second vantage so a wedged X28 loop
# cannot leave the core hung.
#
# Rapid-restart cap: >=4 restarts inside 15 min → 30-min cooldown (crash-loop
# guard; X28-side heal remains as backstop).
#
# Config: $SUI_HEAL_CONF (default ~/.config/x28/sui-heal.conf) — PANEL_*,
# plus optional X28_SSH_PASS / X28_HOST for the relay leg. Never committed.
# Log: $LOGF (default ~/.cache/x28-sb-selfheal.log)
#
# Restart legs, in order:
#   1. panel API directly from here (may be blocked by an upstream filter —
#      observed rc=52 empty-reply on POST restartSb from this vantage)
#   2. SSH relay to the X28 running its one-shot heal (proven path)
#
# Env seams for tests: PROBE_URL, PROBE_SOCKS, FAILS_NEEDED, STATE_DIR.

set -u
CONF="${SUI_HEAL_CONF:-$HOME/.config/x28/sui-heal.conf}"
LOGF="${LOGF:-$HOME/.cache/x28-sb-selfheal.log}"
STATE_DIR="${STATE_DIR:-$HOME/.cache/x28-sb-selfheal}"
FAILS_NEEDED="${FAILS_NEEDED:-3}"
PROBE_URL="${PROBE_URL:-https://www.gstatic.com/generate_204}"
PROBE_SOCKS="${PROBE_SOCKS:-socks5h://192.168.70.1:1080}"

mkdir -p "$STATE_DIR" "$(dirname "$LOGF")" 2>/dev/null
log() { echo "$(date '+%F %T') $*" >> "$LOGF"; }

[ -f "$CONF" ] || { log "no conf at $CONF — nothing to do"; exit 0; }
. "$CONF" 2>/dev/null || exit 0
PANEL_HOST="${PANEL_HOST:-85.121.124.158}"
PANEL_PORT="${PANEL_PORT:-2095}"
PANEL_USER="${PANEL_USER:-suiadmin}"
[ -n "${PANEL_PASS:-}" ] || { log "empty panel pass"; exit 0; }

probe_dead() {
    code=$(curl -s -m 10 -x "$PROBE_SOCKS" -o /dev/null -w '%{http_code}' "$PROBE_URL" 2>/dev/null)
    [ "$code" = "200" ] || [ "$code" = "204" ] && return 1
    return 0
}

panel_login() {
    rm -f "$STATE_DIR/jar"
    curl -s -m 12 -c "$STATE_DIR/jar" -X POST "http://$PANEL_HOST:$PANEL_PORT/app/api/login" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode "user=$PANEL_USER" --data-urlencode "pass=$PANEL_PASS" \
        | grep -q '"success":true'
}

restart_core() {
    curl -s -m 15 -b "$STATE_DIR/jar" -X POST "http://$PANEL_HOST:$PANEL_PORT/app/api/restartSb" \
        | grep -q '"success":true'
}

# relay via the X28: its one-shot heal uses the proven device-side panel path
relay_heal() {
    local host="${X28_HOST:-192.168.70.1}" pass="${X28_SSH_PASS:-}"
    [ -n "$pass" ] || return 1
    sshpass -p "$pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAuthentication=no -o ConnectTimeout=8 \
        "root@$host" "sh /data/proxy/x28-vps-heal.sh heal" >/dev/null 2>&1
}

# rapid-restart ring: count restart stamps in last 900 s
recent_restarts() {
    now=$(date +%s); n=0
    for f in "$STATE_DIR"/rst.*; do
        [ -f "$f" ] || continue
        ts=${f##*rst.}
        case "$ts" in *[!0-9]*) continue ;; esac
        [ $((now - ts)) -le 900 ] && n=$((n + 1))
    done
    echo "$n"
}

main() {
    if probe_dead; then
        fails=$(( $(cat "$STATE_DIR/fails" 2>/dev/null || echo 0) + 1 ))
        echo "$fails" > "$STATE_DIR/fails"
        log "tunnel dead (streak $fails/$FAILS_NEEDED)"
        [ "$fails" -lt "$FAILS_NEEDED" ] && exit 0

        if [ "$(recent_restarts)" -ge 4 ]; then
            log "crash-loop guard: >=4 restarts/15min — backing off 30 min"
            find "$STATE_DIR" -name 'rst.*' -newermt '-16 min' 2>/dev/null | xargs -r touch 2>/dev/null
            exit 0
        fi

        if panel_login && restart_core; then
            touch "$STATE_DIR/rst.$(date +%s)"
            echo 0 > "$STATE_DIR/fails"
            find "$STATE_DIR" -name 'rst.*' | while read -r f; do
                ts=${f##*rst.}; now=$(date +%s)
                [ $((now - ts)) -gt 3600 ] && rm -f "$f"
            done
            log "RESTARTED sing-box via panel (direct)"
        elif relay_heal; then
            touch "$STATE_DIR/rst.$(date +%s)"
            echo 0 > "$STATE_DIR/fails"
            log "RESTARTED sing-box via X28 SSH relay"
        else
            log "all restart legs failed — will retry next tick"
        fi
    else
        echo 0 > "$STATE_DIR/fails"
    fi
}

if [ "${ONESHOT:-0}" = "1" ] || [ -n "${1:-}" ]; then main; else main; fi
