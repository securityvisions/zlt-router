#!/bin/sh
# passwall-failopen.sh — VPN health watchdog with node rotation.
#
# Canonical copy lives in this repo (router/passwall-failopen.sh); deployed to
# the AX3000T as /root/passwall-failopen.sh (minute cron). Checks whether the
# active PassWall node actually proxies internet; on failure it rotates to the
# next node in the chain and only disables PassWall (fail-open to direct) once
# every node has been tried. Auto-recovery is handled by passwall-autorecover.sh.
#
# Chain order (cheapest/most reliable first): Cloudflare-fronted cdn_ws, direct
# VPS REALITY, VPS Hysteria2, then the X28 edge proxy (via_x28).

set -eu

LOCK_DIR=/tmp/passwall-health.lock
COUNT_FILE=/tmp/passwall-fail-count
MARKER=/root/.passwall-disabled-by-failopen
VPN_CHECK=/tmp/passwall-vpn-health-ip

# Failover chain: rotate through these before failing open to direct.
CHAIN="${PW_CHAIN:-cdn_ws eFCgnGrZ hyst_vps via_x28}"
# Quality-aware rotation: a degraded-but-alive link rotates after two
# consecutive degraded checks instead of being left on the slow node.
QSTATE_FILE=/tmp/passwall-quality-count
FB_FILE=/tmp/passwall-failback-count
ESC_FILE=/tmp/passwall-escalation
QALERT_FILE=/tmp/passwall-quality-alert
QEV_FILE=/tmp/passwall-quality-event
PW_FLOOR="${PW_FLOOR:-10}"        # Mbps; below this the active node is "degraded"
PW_LAT_BAD="${PW_LAT_BAD:-2.0}"   # s; latency at/over this is a suspicion trigger
PW_OPERATOR_GRACE_S="${PW_OPERATOR_GRACE_S:-300}"  # wait for a re-camp before fail-open
PW_ALERT_COOLDOWN_S="${PW_ALERT_COOLDOWN_S:-3600}" # degraded-mode alert throttle
HN_LIB="${HN_LIB:-/root/hnlib.sh}"
[ -f "$HN_LIB" ] && . "$HN_LIB"

mkdir "$LOCK_DIR" 2>/dev/null || exit 0
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT INT TERM

# pw_next <current> — prints the next node in CHAIN after current, or "" at end.
pw_next() {
    local cur="$1" next="" found=0 n
    for n in $CHAIN; do
        if [ "$found" = 1 ]; then next="$n"; break; fi
        [ "$n" = "$cur" ] && found=1
    done
    echo "$next"
}

# pw_healthy — true when the active node actually proxies internet.
pw_healthy() {
    pgrep -f '/TCP.*SOCKS.json' >/dev/null 2>&1 &&
        wget -q -T 12 -O "$VPN_CHECK" https://api.ipify.org &&
        grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' "$VPN_CHECK"
}

# pw_node_healthy <node> — true when a specific node passes PassWall's isolated
# test (the same probe auto-recovery uses). Failback depends on this so it can
# judge the preferred node while the active node is a fallback.
pw_node_healthy() {
    local node="$1"
    [ -n "$node" ] || return 1
    mkdir -p /tmp/etc/passwall/bin
    ln -sf /usr/bin/sing-box /tmp/etc/passwall/bin/sing-box
    /usr/share/passwall/test.sh url_test_node "$node" urltest_node 2>/dev/null |
        grep -Eq '^20[04]:'
}

# pw_rotate — move tcp_node to the next node in the chain and restart PassWall.
# Returns 0 on rotation, 1 when there is no next node (chain exhausted).
pw_rotate() {
    local cur next
    cur=$(uci -q get passwall.@global[0].tcp_node || true)
    next=$(pw_next "$cur")
    [ -n "$next" ] || return 1
    uci set passwall.@global[0].tcp_node="$next"
    uci commit passwall
    /etc/init.d/passwall restart >/dev/null 2>&1 || true
    rm -f "$FB_FILE"   # rotation invalidates any failback count
    logger -t passwall-health "rotated node ${cur:-?} -> $next"
    hn_event_record node_rotated "node ${cur:-?} -> $next" passwall-health >/dev/null 2>&1 || true
    return 0
}

# pw_qrotate_decision <qf_count> <sample_mbps> <floor_mbps> — pure. Quality-
# rotation decision: ROTATE on the 2nd consecutive degraded check (hysteresis
# against a single noisy sample), STAY|degraded on the first, STAY|ok when
# healthy or unmeasurable (aliveness is pw_healthy's job, not this decision's).
pw_qrotate_decision() {
    local count="${1:-0}" sample="$2" floor="${3:-10}"
    if [ -n "$sample" ] && [ "$sample" != "0" ]; then
        if awk -v s="$sample" -v f="$floor" 'BEGIN{ exit (s < f) ? 0 : 1 }'; then
            [ "$count" -ge 1 ] && { echo "ROTATE"; return; }
            echo "STAY|degraded"
            return
        fi
    fi
    echo "STAY|ok"
}

# pw_failback_decision <fb_count> <on_preferred> <preferred_healthy> — pure.
# Return to the preferred node on the 2nd consecutive healthy check (hysteresis
# stops flapping); reset the counter when the preferred is unhealthy or we're
# already on it.
pw_failback_decision() {
    local count="${1:-0}" onpref="${2:-0}" healthy="${3:-0}"
    [ "$onpref" = "1" ] && { echo "NONE"; return; }
    [ "$healthy" = "1" ] || { echo "RESET"; return; }
    [ "$count" -ge 1 ] && { echo "FAILBACK"; return; }
    echo "COUNT"
}

# pw_escalate_decision <all_nodes_degraded> <opstate> <quality_bad> — pure.
# The escalation ladder's decision: when every node in the chain is degraded
# and quality is still bad, re-select the cellular operator first (OPERATOR),
# wait one grace period for the re-camp (WAIT), and only then fail open
# (FAILOPEN). Quality fine, or nodes still available, means NONE.
pw_escalate_decision() {
    local allbad="${1:-0}" opstate="${2:-none}" qbad="${3:-0}"
    [ "$qbad" = "1" ] || { echo "NONE"; return; }
    [ "$allbad" = "1" ] || { echo "NONE"; return; }
    case "$opstate" in
        none) echo "OPERATOR" ;;
        fresh) echo "WAIT" ;;
        *) echo "FAILOPEN" ;;
    esac
}

# pw_escalation_opstate — none | fresh | stale, from the last operator trigger.
pw_escalation_opstate() {
    local ts now
    ts=$(sed -n 's/^operator //p' "$ESC_FILE" 2>/dev/null | tail -1)
    [ -z "$ts" ] && { echo none; return; }
    now=$(date +%s)
    [ $((now - ts)) -lt "${PW_OPERATOR_GRACE_S:-300}" ] && echo fresh || echo stale
}

# pw_escalate_operator — trigger the X28 operator re-selection rung and stamp
# the state so the next check WAITs for the re-camp instead of failing open.
pw_escalate_operator() {
    if [ -x /root/x28reselect.sh ]; then
        /root/x28reselect.sh >/dev/null 2>&1 || true
    fi
    hn_cooldown_note "$ESC_FILE" operator
    logger -t passwall-health "escalation: operator re-selection triggered (node rung exhausted)"
    hn_event_record operator_reselected "operator re-selection triggered (node rung exhausted)" passwall-health >/dev/null 2>&1 || true
}

pw_failopen() {
    uci set passwall.@global[0].enabled='0'
    uci set passwall.@global[0].acl_enable='0'
    uci commit passwall
    /etc/init.d/passwall stop
    uci -q delete dhcp.@dnsmasq[0].extraconftext || true
    uci commit dhcp
    /etc/init.d/dnsmasq restart
    date +%s > "$MARKER"
    rm -f "$COUNT_FILE"
    logger -t passwall-health "fail-open: PassWall disabled; waiting for direct internet and a healthy node"
    hn_event_record internet_down "fail-open: PassWall disabled; direct internet" passwall-health >/dev/null 2>&1 || true
}

main() {
    local count qf lat passive sample qd
    if [ "$(uci -q get passwall.@global[0].enabled || true)" != "1" ]; then
        rm -f "$COUNT_FILE" "$QSTATE_FILE"
        exit 0
    fi

    if pw_healthy; then
        rm -f "$COUNT_FILE"
        # Quality-aware rotation: alive-but-degraded rotates after two
        # consecutive degraded checks. Cheap signals first — the targeted
        # sample costs bandwidth, so fire it only on suspicion (probing
        # budget). A chain exhausted of nodes stays on the current node:
        # quality grounds never fail open, the escalation ladder does that.
        qf=$(cat "$QSTATE_FILE" 2>/dev/null || echo 0)
        lat=$(hn_q_latency)
        passive=$(hn_q_passive_mbps "${PW_TELEMETRY:-/etc/telemetry/hourly.log}")
        if [ "$(hn_q_suspicious "$lat" "$passive" "$PW_LAT_BAD" "$PW_FLOOR")" = "1" ]; then
            sample=$(hn_q_sample_mbps)
        fi
        qd=$(pw_qrotate_decision "$qf" "$sample" "$PW_FLOOR")
        # Quality events follow transitions, not the alert cooldown: one
        # degraded per episode (first bad sample), one recovered on the first
        # healthy check after. The Telegram alert keeps its own 1h throttle.
        prev=$(cat "$QEV_FILE" 2>/dev/null || true)
        case "$qd" in
            *degraded*|ROTATE)
                if [ "$prev" != "degraded" ]; then
                    echo "degraded" > "$QEV_FILE"
                    hn_event_record quality_degraded "active node at ${sample:-?} Mbps (floor ${PW_FLOOR})" passwall-health >/dev/null 2>&1 || true
                fi
                ;;
            *ok*)
                if [ "$prev" = "degraded" ]; then
                    echo "recovered" > "$QEV_FILE"
                    hn_event_record quality_recovered "link quality recovered (sample=${sample:-?} Mbps)" passwall-health >/dev/null 2>&1 || true
                fi
                ;;
        esac
        # Degraded-mode alert — distinct from the link-down alert; fires only
        # on a measured degraded sample and throttles via the shared cooldown.
        if [ "$qd" != "STAY|ok" ] && hn_cooldown_ok "$QALERT_FILE" "$PW_ALERT_COOLDOWN_S" degraded; then
            hn_cooldown_note "$QALERT_FILE" degraded
            [ -x /root/tg.sh ] && /root/tg.sh --text "⚠️ Link degraded: active node at ${sample:-?} Mbps (floor ${PW_FLOOR})." >/dev/null 2>&1
        fi
        case "$qd" in
            ROTATE)
                echo "0" > "$QSTATE_FILE"
                if pw_rotate; then
                    logger -t passwall-health "quality-rotate: active node degraded (sample=${sample:-?} floor=$PW_FLOOR)"
                else
                    # Node rung exhausted: escalate to the operator before any
                    # fail-open (quality grounds never fail open directly).
                    case "$(pw_escalate_decision 1 "$(pw_escalation_opstate)" 1)" in
                        OPERATOR) pw_escalate_operator ;;
                        WAIT) logger -t passwall-health "escalation: waiting for operator re-camp" ;;
                        *) pw_failopen ;;
                    esac
                fi
                exit 0
                ;;
            STAY|degraded)
                echo "$((qf + 1))" > "$QSTATE_FILE"
                ;;
            *)
                echo "0" > "$QSTATE_FILE"
                ;;
        esac

        # Auto-failback: on a fallback node, return to the preferred node on
        # its 2nd consecutive healthy isolated test (hysteresis). The counter
        # resets when the preferred is unhealthy or the chain rotates.
        cur=$(uci -q get passwall.@global[0].tcp_node || true)
        pref=$(printf '%s\n' "$CHAIN" | awk '{print $1}')
        if [ -n "$cur" ] && [ -n "$pref" ]; then
            fbc=$(cat "$FB_FILE" 2>/dev/null || echo 0)
            [ "$cur" = "$pref" ] && onpref=1 || onpref=0
            if pw_node_healthy "$pref"; then prefok=1; else prefok=0; fi
            case "$(pw_failback_decision "$fbc" "$onpref" "$prefok")" in
                FAILBACK)
                    echo "0" > "$FB_FILE"
                    uci set passwall.@global[0].tcp_node="$pref"
                    uci commit passwall
                    /etc/init.d/passwall restart >/dev/null 2>&1 || true
                    logger -t passwall-health "failback: preferred node $pref recovered; returning"
                    ;;
                COUNT)
                    echo "$((fbc + 1))" > "$FB_FILE"
                    ;;
                RESET)
                    echo "0" > "$FB_FILE"
                    ;;
            esac
        fi
        exit 0
    fi

    count=$(cat "$COUNT_FILE" 2>/dev/null || echo 0)
    count=$((count + 1))
    echo "$count" > "$COUNT_FILE"
    logger -t passwall-health "VPN health check failed ${count}/5"

    # After two consecutive failures, move to the next node (and keep the
    # network on PassWall while we try it). The escalation ladder runs before
    # fail-open once the chain is exhausted and five checks have failed.
    if [ "$count" -ge 2 ] && pw_rotate; then
        rm -f "$COUNT_FILE"
        exit 0
    fi

    if [ "$count" -ge 5 ]; then
        case "$(pw_escalate_decision 1 "$(pw_escalation_opstate)" 1)" in
            OPERATOR) pw_escalate_operator ;;
            WAIT) logger -t passwall-health "escalation: waiting for operator re-camp" ;;
            *) pw_failopen ;;
        esac
    fi
}

case "${1:-}" in
    --next) pw_next "$2" ;;
    --qrotate) pw_qrotate_decision "$2" "$3" "${4:-$PW_FLOOR}" ;;
    --failback) pw_failback_decision "$2" "$3" "$4" ;;
    --escalate) pw_escalate_decision "$2" "$3" "$4" ;;
    --health) pw_healthy && echo healthy || echo unhealthy ;;
    *) main ;;
esac
