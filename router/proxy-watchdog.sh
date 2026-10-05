#!/bin/sh
# proxy-watchdog.sh — Deep module for PassWall VPN resilience & fail-open watchdog.
#
# Unifies health probing, quality-aware rotation, cellular operator escalation,
# fail-open direct fallback, and auto-recovery into an explicit state machine:
#   HEALTHY    — active node proxies internet at or above quality floor
#   DEGRADED   — node alive but bandwidth/latency below acceptable thresholds
#   ROTATING   — rotating through the proxy chain to find a functional node
#   FAILOPEN   — PassWall disabled, direct internet bypass active
#   RECOVERING — attempting re-activation once direct IP and node test pass
#
# Canonical copy: router/proxy-watchdog.sh (deployed to AX3000T as /root/proxy-watchdog.sh).

LOCK_DIR="${PW_LOCK_DIR:-/tmp/passwall-health.lock}"
STATE_DIR="${PW_STATE_DIR:-/tmp/passwall-watchdog}"
COUNT_FILE="$STATE_DIR/fail-count"
QSTATE_FILE="$STATE_DIR/quality-count"
FB_FILE="$STATE_DIR/failback-count"
ESC_FILE="$STATE_DIR/escalation"
QEV_FILE="$STATE_DIR/quality-event"
QALERT_FILE="$STATE_DIR/quality-alert"
MARKER="${PW_MARKER:-/root/.passwall-disabled-by-failopen}"
VPN_CHECK="$STATE_DIR/vpn-health-ip"
DIRECT_CHECK="$STATE_DIR/direct-health-ip"

# Failover chain: rotate through these before failing open to direct.
CHAIN="${PW_CHAIN:-cdn_ws eFCgnGrZ hyst_vps via_x28}"
PW_FLOOR="${PW_FLOOR:-10}"        # Mbps; below this the active node is "degraded"
PW_LAT_BAD="${PW_LAT_BAD:-2.0}"   # s; latency at/over this is a suspicion trigger
PW_OPERATOR_GRACE_S="${PW_OPERATOR_GRACE_S:-300}"  # wait for a re-camp before fail-open
PW_ALERT_COOLDOWN_S="${PW_ALERT_COOLDOWN_S:-3600}" # degraded-mode alert throttle

HN_LIB="${HN_LIB:-/root/hnlib.sh}"
[ -f "$HN_LIB" ] && . "$HN_LIB"

mkdir -p "$STATE_DIR"

# ----------------- Pure Decision Functions (Test Seams) -----------------

# pw_next <current> [chain] — next node in chain, or "" if current is last/unknown
pw_next() {
    local cur="$1" chain="${2:-$CHAIN}" next="" found=0 n
    for n in $chain; do
        if [ "$found" = 1 ]; then next="$n"; break; fi
        [ "$n" = "$cur" ] && found=1
    done
    echo "$next"
}

# pw_qrotate_decision <qf_count> <sample_mbps> <floor_mbps> — pure.
# ROTATE on 2nd consecutive degraded check; STAY|degraded on 1st; STAY|ok otherwise.
pw_qrotate_decision() {
    local count="${1:-0}" sample="$2" floor="${3:-$PW_FLOOR}"
    if [ -n "$sample" ] && [ "$sample" != "0" ]; then
        if awk -v s="$sample" -v f="$floor" 'BEGIN{ exit (s < f) ? 0 : 1 }' 2>/dev/null; then
            [ "$count" -ge 1 ] && { echo "ROTATE"; return; }
            echo "STAY|degraded"
            return
        fi
    fi
    echo "STAY|ok"
}

# pw_failback_decision <fb_count> <on_preferred> <preferred_healthy> — pure.
# Return to preferred node on 2nd consecutive healthy check.
pw_failback_decision() {
    local count="${1:-0}" onpref="${2:-0}" healthy="${3:-0}"
    [ "$onpref" = "1" ] && { echo "NONE"; return; }
    [ "$healthy" = "1" ] || { echo "RESET"; return; }
    [ "$count" -ge 1 ] && { echo "FAILBACK"; return; }
    echo "COUNT"
}

# pw_escalate_decision <all_nodes_degraded> <opstate> <quality_bad> — pure.
# When all nodes degraded and quality still bad: OPERATOR -> WAIT -> FAILOPEN.
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

# ----------------- Hardware / Network Probing -----------------

pw_is_enabled() {
    if [ -n "${PW_ENABLED:-}" ]; then
        [ "$PW_ENABLED" = "1" ] && return 0 || return 1
    fi
    if command -v uci >/dev/null 2>&1; then
        [ "$(uci -q get passwall.@global[0].enabled 2>/dev/null || true)" = "1" ] && return 0 || return 1
    fi
    return 0
}

pw_healthy() {
    pgrep -f '/TCP.*SOCKS.json' >/dev/null 2>&1 &&
        wget -q -T 12 -O "$VPN_CHECK" https://api.ipify.org &&
        grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' "$VPN_CHECK"
}

pw_direct_healthy() {
    wget -q -T 10 -O "$DIRECT_CHECK" https://api.ipify.org &&
        grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' "$DIRECT_CHECK"
}

pw_node_healthy() {
    local node="$1"
    [ -n "$node" ] || return 1
    mkdir -p /tmp/etc/passwall/bin
    [ -x /usr/bin/sing-box ] && ln -sf /usr/bin/sing-box /tmp/etc/passwall/bin/sing-box
    /usr/share/passwall/test.sh url_test_node "$node" urltest_node 2>/dev/null |
        grep -Eq '^20[04]:'
}

pw_escalation_opstate() {
    local ts now
    ts=$(sed -n 's/^operator //p' "$ESC_FILE" 2>/dev/null | tail -1)
    [ -z "$ts" ] && { echo none; return; }
    now=$(date +%s)
    [ $((now - ts)) -lt "${PW_OPERATOR_GRACE_S:-300}" ] && echo fresh || echo stale
}

pw_escalate_operator() {
    if [ -x /root/x28reselect.sh ]; then
        /root/x28reselect.sh >/dev/null 2>&1 || true
    fi
    if command -v hn_cooldown_note >/dev/null 2>&1; then
        hn_cooldown_note "$ESC_FILE" operator
    else
        echo "operator $(date +%s)" >> "$ESC_FILE"
    fi
    logger -t passwall-health "escalation: operator re-selection triggered"
    if command -v hn_event_record >/dev/null 2>&1; then
        hn_event_record operator_reselected "operator re-selection triggered (node rung exhausted)" passwall-health >/dev/null 2>&1 || true
    fi
}

# ----------------- State Mutation Operations -----------------

pw_rotate() {
    local cur next
    cur=$(uci -q get passwall.@global[0].tcp_node || true)
    next=$(pw_next "$cur")
    [ -n "$next" ] || return 1
    uci set passwall.@global[0].tcp_node="$next"
    uci commit passwall
    /etc/init.d/passwall restart >/dev/null 2>&1 || true
    rm -f "$FB_FILE"
    logger -t passwall-health "rotated node ${cur:-?} -> $next"
    if command -v hn_event_record >/dev/null 2>&1; then
        hn_event_record node_rotated "node ${cur:-?} -> $next" passwall-health >/dev/null 2>&1 || true
    fi
    return 0
}

pw_failopen() {
    uci set passwall.@global[0].enabled='0'
    uci set passwall.@global[0].acl_enable='0'
    uci commit passwall
    /etc/init.d/passwall stop >/dev/null 2>&1 || true
    uci -q delete dhcp.@dnsmasq[0].extraconftext || true
    uci commit dhcp
    /etc/init.d/dnsmasq restart >/dev/null 2>&1 || true
    date +%s > "$MARKER"
    rm -f "$COUNT_FILE" "$QSTATE_FILE"
    logger -t passwall-health "fail-open: PassWall disabled; direct mode active"
    if command -v hn_event_record >/dev/null 2>&1; then
        hn_event_record internet_down "fail-open: PassWall disabled; direct internet" passwall-health >/dev/null 2>&1 || true
    fi
}

pw_recover() {
    [ -e "$MARKER" ] || return 0
    if pw_is_enabled; then
        rm -f "$MARKER"
        return 0
    fi

    if ! pw_direct_healthy; then
        logger -t passwall-health "auto-recovery paused: direct internet unavailable"
        return 1
    fi

    local node
    node="$(uci -q get passwall.@global[0].tcp_node || true)"
    [ -n "$node" ] || return 1

    if ! pw_node_healthy "$node"; then
        logger -t passwall-health "auto-recovery paused: node $node failed isolated test"
        return 1
    fi

    logger -t passwall-health "direct internet and node $node healthy; starting PassWall"
    uci set passwall.@global[0].enabled='1'
    uci set passwall.@global[0].acl_enable='0'
    uci set passwall.@global[0].udp_node='tcp'
    uci set passwall.@global[0].use_direct_list="1"
    uci commit passwall

    uci -q delete dhcp.@dnsmasq[0].extraconftext || true
    uci commit dhcp
    /etc/init.d/dnsmasq restart >/dev/null 2>&1 || true

    if ! timeout 90 /etc/init.d/passwall start </dev/null >/tmp/passwall-autorecover-start.log 2>&1; then
        uci set passwall.@global[0].enabled='0'
        uci commit passwall
        /etc/init.d/passwall stop >/dev/null 2>&1 || true
        /etc/init.d/dnsmasq restart >/dev/null 2>&1 || true
        logger -t passwall-health "auto-recovery failed during PassWall start; staying direct"
        return 1
    fi

    local attempt=0
    while [ "$attempt" -lt 12 ]; do
        attempt=$((attempt + 1))
        if pgrep -f '/TCP.*SOCKS.json' >/dev/null 2>&1 &&
           nft list chain inet passwall PSW_NAT 2>/dev/null | grep -q 'redirect to :1041' &&
           nft list chain inet passwall PSW_MANGLE 2>/dev/null | grep -q 'tproxy ip to :1041'; then
            [ -x /root/passwall-bypass-ensure.sh ] && /root/passwall-bypass-ensure.sh >/dev/null 2>&1 || true
            if pw_healthy; then
                rm -f "$MARKER" "$COUNT_FILE" "$QSTATE_FILE" "$FB_FILE"
                logger -t passwall-health "auto-recovery complete: PassWall active and verified"
                if command -v hn_event_record >/dev/null 2>&1; then
                    hn_event_record internet_up "auto-recovery: PassWall restored" passwall-health >/dev/null 2>&1 || true
                fi
                return 0
            fi
        fi
        sleep 2
    done

    logger -t passwall-health "auto-recovery post-start verification timed out; reverting to direct"
    pw_failopen
    return 1
}

# ----------------- Supervisor State & Tick -----------------

pw_get_state() {
    if [ -e "$MARKER" ] || ! pw_is_enabled; then
        echo "FAILOPEN"
        return
    fi
    local qf
    qf=$(cat "$QSTATE_FILE" 2>/dev/null || echo 0)
    if [ "$qf" -gt 0 ]; then
        echo "DEGRADED"
        return
    fi
    echo "HEALTHY"
}

pw_tick() {
    # If in failopen state, run recovery check
    if [ -e "$MARKER" ] || ! pw_is_enabled; then
        pw_recover || true
        return 0
    fi

    # PassWall is active; perform health check
    if pw_healthy; then
        rm -f "$COUNT_FILE"
        local qf lat passive sample qd prev cur pref fbc onpref prefok
        qf=$(cat "$QSTATE_FILE" 2>/dev/null || echo 0)
        lat=$(hn_q_latency 2>/dev/null || echo 0)
        passive=$(hn_q_passive_mbps "${PW_TELEMETRY:-/etc/telemetry/hourly.log}" 2>/dev/null || echo 0)

        if [ "$(hn_q_suspicious "$lat" "$passive" "$PW_LAT_BAD" "$PW_FLOOR" 2>/dev/null || echo 0)" = "1" ]; then
            sample=$(hn_q_sample_mbps 2>/dev/null || echo "")
        else
            sample=""
        fi

        qd=$(pw_qrotate_decision "$qf" "$sample" "$PW_FLOOR")
        prev=$(cat "$QEV_FILE" 2>/dev/null || true)
        case "$qd" in
            *degraded*|ROTATE)
                if [ "$prev" != "degraded" ]; then
                    echo "degraded" > "$QEV_FILE"
                    command -v hn_event_record >/dev/null 2>&1 &&
                        hn_event_record quality_degraded "active node at ${sample:-?} Mbps (floor ${PW_FLOOR})" passwall-health >/dev/null 2>&1 || true
                fi
                ;;
            *ok*)
                if [ "$prev" = "degraded" ]; then
                    echo "recovered" > "$QEV_FILE"
                    command -v hn_event_record >/dev/null 2>&1 &&
                        hn_event_record quality_recovered "link quality recovered (sample=${sample:-?} Mbps)" passwall-health >/dev/null 2>&1 || true
                fi
                ;;
        esac

        if [ "$qd" != "STAY|ok" ] && command -v hn_cooldown_ok >/dev/null 2>&1 &&
           hn_cooldown_ok "$QALERT_FILE" "$PW_ALERT_COOLDOWN_S" degraded; then
            hn_cooldown_note "$QALERT_FILE" degraded
            [ -x /root/tg.sh ] && /root/tg.sh --text "⚠️ Link degraded: active node at ${sample:-?} Mbps (floor ${PW_FLOOR})." >/dev/null 2>&1 || true
        fi

        case "$qd" in
            ROTATE)
                echo "0" > "$QSTATE_FILE"
                if pw_rotate; then
                    logger -t passwall-health "quality-rotate: active node degraded (sample=${sample:-?} floor=$PW_FLOOR)"
                else
                    case "$(pw_escalate_decision 1 "$(pw_escalation_opstate)" 1)" in
                        OPERATOR) pw_escalate_operator ;;
                        WAIT) logger -t passwall-health "escalation: waiting for operator re-camp" ;;
                        *) pw_failopen ;;
                    esac
                fi
                return 0
                ;;
            STAY|degraded)
                echo "$((qf + 1))" > "$QSTATE_FILE"
                ;;
            *)
                echo "0" > "$QSTATE_FILE"
                ;;
        esac

        # Auto-failback to preferred node
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
        return 0
    fi

    # Unhealthy check
    local count
    count=$(cat "$COUNT_FILE" 2>/dev/null || echo 0)
    count=$((count + 1))
    echo "$count" > "$COUNT_FILE"
    logger -t passwall-health "VPN health check failed ${count}/5"

    if [ "$count" -ge 2 ] && pw_rotate; then
        rm -f "$COUNT_FILE"
        return 0
    fi

    if [ "$count" -ge 5 ]; then
        case "$(pw_escalate_decision 1 "$(pw_escalation_opstate)" 1)" in
            OPERATOR) pw_escalate_operator ;;
            WAIT) logger -t passwall-health "escalation: waiting for operator re-camp" ;;
            *) pw_failopen ;;
        esac
    fi
}

pw_status() {
    local state node pref count qcount fbcount
    state=$(pw_get_state)
    node="none"
    if command -v uci >/dev/null 2>&1; then
        node=$(uci -q get passwall.@global[0].tcp_node 2>/dev/null || echo "none")
    elif [ -n "${PW_NODE:-}" ]; then
        node="$PW_NODE"
    fi
    pref=$(printf '%s\n' "$CHAIN" | awk '{print $1}')
    count=$(cat "$COUNT_FILE" 2>/dev/null || echo 0)
    qcount=$(cat "$QSTATE_FILE" 2>/dev/null || echo 0)
    fbcount=$(cat "$FB_FILE" 2>/dev/null || echo 0)

    if [ "${1:-}" = "--json" ]; then
        printf '{"state":"%s","active_node":"%s","preferred_node":"%s","fail_count":%d,"quality_count":%d,"failback_count":%d}\n' \
            "$state" "$node" "$pref" "$count" "$qcount" "$fbcount"
    else
        printf 'state=%s\nactive_node=%s\npreferred_node=%s\nfail_count=%d\nquality_count=%d\nfailback_count=%d\n' \
            "$state" "$node" "$pref" "$count" "$qcount" "$fbcount"
    fi
}

# ----------------- CLI Entrypoint -----------------

main() {
    mkdir "$LOCK_DIR" 2>/dev/null || exit 0
    trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT INT TERM
    pw_tick
}

case "${1:-}" in
    --next)     pw_next "$2" "${3:-}" ;;
    --qrotate)  pw_qrotate_decision "$2" "$3" "${4:-$PW_FLOOR}" ;;
    --failback) pw_failback_decision "$2" "$3" "$4" ;;
    --escalate) pw_escalate_decision "$2" "$3" "$4" ;;
    --state)    pw_get_state ;;
    --health)   pw_healthy && echo healthy || echo unhealthy ;;
    status)     pw_status "${2:-}" ;;
    rotate)     pw_rotate ;;
    failopen)   pw_failopen ;;
    recover)    pw_recover ;;
    tick)       main ;;
    "")         main ;;
    *)          echo "Usage: $0 {tick|status [--json]|rotate|failopen|recover|--next|--qrotate|--failback|--escalate}" >&2; exit 1 ;;
esac
