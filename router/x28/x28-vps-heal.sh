#!/bin/sh
# x28-vps-heal.sh — VPS auto-heal watchdog for sing-box core hangs.
# Polls mihomo auto group health; if all nodes dead for 4 min while local
# DNS (127.0.0.1:5353) still answers, logs into s-ui panel and POST restartSb.
# Best-effort, never blocks boot, procd respawned. A Telegram card fires on
# every heal action (and on skip, so a dead-DNS wedge is visible too).
# Canonical copy: router/x28/x28-vps-heal.sh — deploys to /data/proxy/x28-vps-heal.sh
PANEL_HOST="${PANEL_HOST:-85.121.124.158}"
PANEL_PORT="${PANEL_PORT:-2095}"
PANEL_BASE="http://${PANEL_HOST}:${PANEL_PORT}/app"
PANEL_USER="${PANEL_USER:-suiadmin}"
PANEL_PASS="${PANEL_PASS:-}"
DEAD_THRESHOLD="${HEAL_DEAD_THRESHOLD:-4}"
SLEEP_SEC="${HEAL_SLEEP:-60}"
COOKIE_JAR=/tmp/sui-heal.jar
STATE_FILE=/tmp/vps-heal-deadcount
DNS_CHECK_HOST="${DNS_CHECK_HOST:-127.0.0.1}"

# notify — best-effort Telegram card (never blocks the loop)
notify() {
    sh /data/proxy/tg-notify.sh "$1" "$2" >/dev/null 2>&1 || true
}

# panel_login — form-encoded, saves cookie jar
panel_login() {
    [ -n "$PANEL_PASS" ] || return 1
    rm -f "$COOKIE_JAR"
    curl -s -m 12 -c "$COOKIE_JAR" -X POST "$PANEL_BASE/api/login" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode "user=$PANEL_USER" --data-urlencode "pass=$PANEL_PASS" \
        | grep -q '"success":true'
}

# mihomo_auto_dead — exit 0 if auto group has no alive node
mihomo_auto_dead() {
    auto=$(curl -s -m 5 "http://127.0.0.1:9090/proxies/auto" 2>/dev/null | grep -o '"alive":true' | head -1)
    [ -z "$auto" ]
}

# local_dns_alive — mihomo DNS (127.0.0.1:5353) or dnsmasq answers
local_dns_alive() {
    nslookup google.com "$DNS_CHECK_HOST" >/dev/null 2>&1 && return 0
    nslookup google.com 127.0.0.1 >/dev/null 2>&1
}

# heal_once — try one restart cycle
heal_once() {
    if ! panel_login; then
        logger -t x28-vps-heal "login failed"
        return 1
    fi
    if curl -s -m 15 -b "$COOKIE_JAR" -X POST "$PANEL_BASE/api/restartSb" | grep -q '"success":true'; then
        logger -t x28-vps-heal "restartSb success"
        return 0
    fi
    logger -t x28-vps-heal "restartSb failed"
    return 1
}

# main loop
heal_loop() {
    dead=0
    [ -f "$STATE_FILE" ] && dead=$(cat "$STATE_FILE" 2>/dev/null | tr -d ' \n' | grep -E '^[0-9]+$' || echo 0)
    while :; do
        if mihomo_auto_dead; then
            dead=$((dead + 1))
        else
            dead=0
        fi
        echo "$dead" > "$STATE_FILE"
        if [ "$dead" -ge "$DEAD_THRESHOLD" ]; then
            if local_dns_alive; then
                logger -t x28-vps-heal "auto dead $dead checks, local DNS alive — healing"
                notify "🩺 VPS core heal" "auto group dead ${dead}×${SLEEP_SEC}s — restarting sing-box via panel"
                if heal_once; then
                    dead=0
                    echo 0 > "$STATE_FILE"
                    sleep 120
                else
                    notify "🩺 VPS core heal FAILED" "restartSb did not succeed; retrying in 5 min"
                    sleep 300
                fi
            else
                logger -t x28-vps-heal "auto dead but local DNS also dead — skip heal"
                notify "🩺 VPS heal skipped" "auto dead but local DNS also dead — likely carrier outage, watchdog handles it"
                dead=0
                echo 0 > "$STATE_FILE"
            fi
        fi
        sleep "$SLEEP_SEC"
    done
}

case "${1:-loop}" in
    loop) heal_loop ;;
    once) mihomo_auto_dead && echo "dead" || echo "alive" ;;
    heal) heal_once ;;
esac
