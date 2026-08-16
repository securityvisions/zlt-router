#!/bin/sh
# vpshealth.sh — VPS proxy-origin health checks + alert.
#
# Canonical copy lives in this repo (router/vpshealth.sh); it deploys to the
# AX3000T as /root/vpshealth.sh (cron). Probes the s-ui panel (:2095) and
# subscription (:2096) ports directly from the router, and the SSH port, and
# alerts when the origin is unreachable. (The proxied-path health is already
# covered by passwall-failopen.sh.)

VPS_HOST="${VPS_HOST:-85.121.124.158}"
VPS_PANEL_PORT="${VPS_PANEL_PORT:-2095}"
VPS_SUB_PORT="${VPS_SUB_PORT:-2096}"
VPS_SSH_PORT="${VPS_SSH_PORT:-22}"
VP_ALERT_COOLDOWN_S="${VP_ALERT_COOLDOWN_S:-1800}"
# Shared alert throttle (hnlib), optional so tests run without it.
HN_LIB="${HN_LIB:-/root/hnlib.sh}"
[ -f "$HN_LIB" ] && . "$HN_LIB"
VP_STATE="${VP_STATE:-/tmp/vpshealth.state}"

# vp_port_ok <port> — true when the TCP port answers.
vp_port_ok() {
    curl -s -m 8 -o /dev/null -w '%{http_code}' "http://$VPS_HOST:$1/" 2>/dev/null |
        grep -qE '^[0-9]{3}$'
}

# vp_decision <panel_ok> <sub_ok> — pure; prints OK | ALERT|down.
vp_decision() {
    if [ "$1" = "1" ] && [ "$2" = "1" ]; then
        echo "OK"
    else
        echo "ALERT|down"
    fi
}

vp_cooldown_ok() {
    hn_cooldown_ok "$VP_STATE" "$VP_ALERT_COOLDOWN_S" alert
}

main() {
    local panel sub decision
    vp_port_ok "$VPS_PANEL_PORT" && panel=1 || panel=0
    vp_port_ok "$VPS_SUB_PORT" && sub=1 || sub=0
    decision=$(vp_decision "$panel" "$sub")
    if [ "$decision" = "ALERT|down" ] && vp_cooldown_ok; then
        hn_cooldown_note "$VP_STATE" alert
        [ -x /root/tg.sh ] && /root/tg.sh --text "🔴 VPS origin unreachable (panel=$panel sub=$sub)." >/dev/null 2>&1
    fi
    echo "$decision"
}

case "${1:-}" in
    --decision) vp_decision "$2" "$3" ;;
    *) main ;;
esac
