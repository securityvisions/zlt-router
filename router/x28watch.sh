#!/bin/sh
# x28watch.sh — ZLT X28 link stickiness + degradation watchdog.
#
# Canonical copy lives in this repo (router/x28watch.sh); it deploys to the
# AX3000T as /root/x28watch.sh and is driven by cron (every 5 min). It reads
# the X28 link state (over SSH to /data/proxy/linkstate.sh), decides whether
# the link has drifted off the preferred operator or degraded, alerts via the
# bot (tg.sh) and re-selects the preferred operator on the X28.
#
# Config: X28_PREF_OPERATOR (substring matched against the operator name;
# default "MCI"), X28_RSRP_BAD (dBm; RSRP values <= this are "bad"; default
# -95), X28_ALERT_COOLDOWN_S (default 1800). Pure decision logic lives in
# x28w_decide() so tests can call it directly.

X28_PREF_OPERATOR="${X28_PREF_OPERATOR:-MCI}"
X28_RSRP_BAD="${X28_RSRP_BAD:--95}"
X28_ALERT_COOLDOWN_S="${X28_ALERT_COOLDOWN_S:-1800}"
X28_FIX_COOLDOWN_S="${X28_FIX_COOLDOWN_S:-600}"
STATE="${X28_STATE:-/tmp/x28watch.state}"
# The link-state reader and reselect helper deployed on THIS router (they talk to
# the X28's vendor HTTP API directly — no SSH dependency).
X28_LINK_SH="${X28_LINK_SH:-/root/x28link.sh}"
X28_RESELECT_SH="${X28_RESELECT_SH:-/root/x28reselect.sh}"
X28_TARGET_PLMN="${X28_TARGET_PLMN:-43211}"
X28_TARGET_ACT="${X28_TARGET_ACT:-13}"

log() { echo "[$(date '+%F %T')] $*" >> /tmp/x28watch.log 2>/dev/null; }

# x28w_decide <operator> <tech> <rsrp> <rsrp_5g>
# Prints exactly one line: OK | FIX|operator | ALERT|degraded.
# Pure — no state, no side effects; used by the tests and the live flow.
x28w_decide() {
    local op="$1" tech="$2" rsrp="$3" rsrp5g="$4"
    # Operator drift: the single most important failure (weak operator = slow link).
    case "$op" in
        *"$X28_PREF_OPERATOR"*) : ;;
        *) echo "FIX|operator"; return 0 ;;
    esac
    # Degradation: poor signal/RSRP on the preferred operator (informational).
    if [ -n "$rsrp" ]; then
        if awk -v r="$rsrp" -v b="$X28_RSRP_BAD" 'BEGIN{ exit !(r <= b) }'; then
            echo "ALERT|degraded"; return 0
        fi
    fi
    echo "OK"
}

# x28w_cooldown_ok <cooldown_s> <action> — true when `action` is out of cooldown.
x28w_cooldown_ok() {
    local cd="$1" action="$2" now last
    now=$(date +%s)
    last=$(sed -n "s/^$action //p" "$STATE" 2>/dev/null | tail -1)
    [ -z "$last" ] && return 0
    [ $((now - last)) -ge "$cd" ]
}

x28w_note() {  # x28w_note <action> — stamp the action time (now).
    echo "$1 $(date +%s)" >> "$STATE" 2>/dev/null
    # keep the state file small
    tail -n 100 "$STATE" > "$STATE.tmp" 2>/dev/null && mv "$STATE.tmp" "$STATE" 2>/dev/null
}

# read_link — run the X28 link-state reader (talks to the X28 HTTP API).
read_link() {
    timeout 20 "$X28_LINK_SH" 2>/dev/null
}
link_field() { printf '%s\n' "$1" | sed -n "s/^$2=//p" | head -1; }

# fix_operator — re-select the preferred operator on the X28 (can take ~90s).
fix_operator() {
    log "re-selecting preferred operator on X28"
    timeout 110 env X28_TARGET_PLMN="$X28_TARGET_PLMN" X28_TARGET_ACT="$X28_TARGET_ACT" \
        sh "$X28_RESELECT_SH" >/dev/null 2>&1
}

main() {
    local fields op tech rsrp decision
    fields=$(read_link)
    [ -z "$fields" ] && { log "link reader returned nothing"; exit 0; }
    op=$(link_field "$fields" operator)
    tech=$(link_field "$fields" tech)
    rsrp=$(link_field "$fields" rsrp)
    decision=$(x28w_decide "$op" "$tech" "$rsrp" "$(link_field "$fields" rsrp_5g)")
    log "operator=$op tech=$tech rsrp=$rsrp -> $decision"
    if [ "$decision" = "OK" ]; then
        :
    elif [ "${decision#FIX|}" != "$decision" ]; then
        if x28w_cooldown_ok "$X28_FIX_COOLDOWN_S" fix; then
            x28w_note fix
            fix_operator
            [ -x /root/tg.sh ] && /root/tg.sh --text "⚠️ X28 drifted to <b>$op</b> — re-selecting $X28_PREF_OPERATOR." >/dev/null 2>&1
        fi
    elif [ "${decision#ALERT|}" != "$decision" ]; then
        if x28w_cooldown_ok "$X28_ALERT_COOLDOWN_S" alert; then
            x28w_note alert
            [ -x /root/tg.sh ] && /root/tg.sh --text "📶 X28 signal degraded (RSRP ${rsrp:-n/a}) — link is weak." >/dev/null 2>&1
        fi
    fi
}

case "${1:-}" in
    --check) x28w_decide "$2" "$3" "$4" "$5" ;;
    *) main ;;
esac
