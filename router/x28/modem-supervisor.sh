#!/bin/sh
# modem-supervisor.sh — Unified cellular modem supervisor for ZLT X28.
#
# Deep module consolidating:
#   1. Link state telemetry & structured JSON/key=val emission
#   2. Operator drift & signal degradation decision logic
#   3. Safe PLMN switching with storm guard (max 3/hr) and 600s cooldown
#   4. Autonomous watchdog loop for MCI 5G / Rightel failover
#
# Interfaces:
#   modem-supervisor.sh status [--json]
#   modem-supervisor.sh check <operator> <tech> <rsrp> <rsrp_5g>
#   modem-supervisor.sh switch <plmn> [act]
#   modem-supervisor.sh tick
#   modem-supervisor.sh daemon

X28_LIB="${X28_LIB:-$(dirname "$0")/x28lib.sh}"
[ -f "$X28_LIB" ] && . "$X28_LIB"

PREFERRED="${WATCHDOG_PREFERRED:-43211}"     # MCI (5G, fast)
FALLBACK="${WATCHDOG_FALLBACK:-43220}"       # Rightel (4G, reliable)
ACT="${WATCHDOG_ACT:-13}"
COOLDOWN="${WATCHDOG_COOLDOWN:-600}"         # 10 min switch cooldown
MAX_PER_HOUR="${WATCHDOG_MAX_H:-3}"          # storm guard cap
FAIL_THRESHOLD="${WATCHDOG_FAILS:-3}"

X28_PREF_OPERATOR="${X28_PREF_OPERATOR:-MCI}"
X28_RSRP_BAD="${X28_RSRP_BAD:--95}"
X28_RSRP5G_BAD="${X28_RSRP5G_BAD:--100}"

STATEDIR="${MODEM_STATE_DIR:-/tmp/x28-watchdog}"
LOG="${MODEM_LOG:-/data/proxy/watchdog.log}"
ENDPOINTS="${WATCHDOG_ENDPOINTS:-https://1.1.1.1 https://216.239.38.120}"

now() { date +%s; }

modem_log() {
    [ -d "$(dirname "$LOG")" ] || return 0
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG" 2>/dev/null
}

modem_status() {
    local fmt="${1:-text}"
    local d401 at op tech sig rsrp rsrp5g dl ul plmn

    d401=$(x28_api 401 GET)
    [ -n "$d401" ] || {
        if [ "$fmt" = "--json" ] || [ "$fmt" = "json" ]; then
            echo '{"error":"api_unreachable"}'
        else
            echo "error=api_unreachable"
        fi
        return 1
    }

    op=$(x28_field "$d401" network_operator)
    tech=$(x28_field "$d401" network_type_str)
    sig=$(x28_field "$d401" signal_lvl)
    rsrp=$(x28_field "$d401" RSRP)
    rsrp5g=$(x28_field "$d401" RSRP_5G)
    dl=$(x28_field "$d401" flow_dl)
    ul=$(x28_field "$d401" flow_ul)

    at=$(x28_api 270 POST ',"atInfo":"QVQrQ09QUz8="')
    plmn=$(printf '%s' "$at" | sed -n "s/.*COPS: [01],2,'\([0-9]*\)'.*/\1/p" | head -1)

    if [ "$fmt" = "--json" ] || [ "$fmt" = "json" ]; then
        printf '{"operator":"%s","tech":"%s","signal":%s,"rsrp":"%s","rsrp_5g":"%s","band":"%s","flow_dl":"%s","flow_ul":"%s","plmn":"%s"}\n' \
            "$op" "$tech" "${sig:-0}" "$rsrp" "$rsrp5g" "${X28_BAND:-}" "$dl" "$ul" "$plmn"
    else
        printf 'operator=%s\n'  "$op"
        printf 'tech=%s\n'      "$tech"
        printf 'signal=%s\n'    "$sig"
        printf 'rsrp=%s\n'      "$rsrp"
        printf 'rsrp_5g=%s\n'   "$rsrp5g"
        printf 'band=%s\n'      "${X28_BAND:-}"
        printf 'flow_dl=%s\n'   "$dl"
        printf 'flow_ul=%s\n'   "$ul"
        printf 'plmn=%s\n'      "$plmn"
    fi
}

modem_decide() {
    local op="$1" tech="$2" rsrp="$3" rsrp5g="$4"
    case "$op" in
        *"$X28_PREF_OPERATOR"*) : ;;
        *) echo "FIX|operator"; return 0 ;;
    esac
    if [ -n "$rsrp" ] && awk -v r="$rsrp" -v b="$X28_RSRP_BAD" 'BEGIN{ exit !(r <= b) }'; then
        echo "ALERT|degraded"; return 0
    fi
    if [ -n "$rsrp5g" ] && awk -v r="$rsrp5g" -v b="$X28_RSRP5G_BAD" 'BEGIN{ exit !(r <= b) }'; then
        echo "ALERT|degraded"; return 0
    fi
    echo "OK"
}

modem_switches_last_hour() {
    local t c f ts
    t=$(now); c=0
    [ -d "$STATEDIR" ] || { echo 0; return 0; }
    for f in "$STATEDIR"/sw.*; do
        [ -f "$f" ] || continue
        ts=${f##*sw.}
        [ $((t - ts)) -lt 3600 ] && c=$((c + 1))
    done
    echo "$c"
}

modem_record_switch() {
    local t f ts
    mkdir -p "$STATEDIR"
    : > "$STATEDIR/sw.$(now)"
    t=$(now)
    for f in "$STATEDIR"/sw.*; do
        [ -f "$f" ] || continue
        ts=${f##*sw.}
        [ $((t - ts)) -gt 7200 ] && rm -f "$f"
    done
}

modem_in_cooldown() {
    local ls t
    [ -f "$STATEDIR/lastswitch" ] || return 1
    ls=$(cat "$STATEDIR/lastswitch" 2>/dev/null || echo 0)
    t=$(now)
    [ $((t - ls)) -lt "$COOLDOWN" ]
}

modem_check_data() {
    local ep code
    if [ -x /data/proxy/probe-service.sh ]; then
        sh /data/proxy/probe-service.sh data >/dev/null 2>&1 && return 0 || return 1
    fi
    for ep in $ENDPOINTS; do
        code=$(curl -k -s -m 8 -o /dev/null -w '%{http_code}' "$ep" 2>/dev/null)
        case "$code" in 200|204|301|302) return 0 ;; esac
    done
    return 1
}

modem_switch() {
    local target="$1" act="${2:-$ACT}"
    local n resp i

    if [ "$WATCHDOG_DRYRUN" = "1" ]; then
        modem_log "DRYRUN: would switch to $target"
        echo "DRYRUN: switch $target"
        return 0
    fi

    if modem_in_cooldown; then
        modem_log "switch to $target SKIPPED: cooldown active"
        echo "ERROR: in cooldown"
        return 1
    fi

    n=$(modem_switches_last_hour)
    if [ "$n" -ge "$MAX_PER_HOUR" ]; then
        modem_log "switch to $target SKIPPED: $n switches in last hour (storm guard)"
        echo "ERROR: storm guard ($n/hr)"
        return 1
    fi

    modem_log "switching operator -> $target"
    x28_session || { echo "ERROR: no session" >&2; return 1; }
    resp=$(curl -s -m 90 -H 'Content-Type: application/json' \
        -d "{\"cmd\":228,\"plmn_select_cmd\":\"4\",\"plmn\":\"$target\",\"act\":\"$act\",\"method\":\"POST\",\"sessionId\":\"$X28_SID\",\"language\":\"en\"}" \
        "$X28_BASE" 2>/dev/null)
    modem_log "reselect cmd 228 response: $resp"
    modem_record_switch
    echo "$(now)" > "$STATEDIR/lastswitch"

    i=0
    while [ $i -lt 8 ]; do
        sleep 10
        if modem_check_data; then
            modem_log "switch to $target OK: data confirmed"
            echo "OK: data confirmed on $target"
            return 0
        fi
        i=$((i + 1))
    done

    modem_log "switch to $target WARNING: no data confirmed after 80s"
    echo "WARNING: no data after switch"
    return 2
}

modem_tick() {
    local status cur_op cur_plmn verdict fails

    status=$(modem_status text)
    cur_op=$(printf '%s' "$status" | sed -n 's/^operator=//p' | head -1)
    cur_plmn=$(printf '%s' "$status" | sed -n 's/^plmn=//p' | head -1)

    if modem_check_data; then
        rm -f "$STATEDIR/fails" 2>/dev/null
        # Evaluate operator preference
        verdict=$(modem_decide "$cur_op" "" "" "")
        if [ "$verdict" = "FIX|operator" ] && [ "$cur_plmn" != "$PREFERRED" ]; then
            # We are on fallback operator with working data. Check probe window
            modem_log "operating on fallback ($cur_op/$cur_plmn) with working data"
        fi
        echo "OK"
        return 0
    else
        mkdir -p "$STATEDIR"
        fails=$(cat "$STATEDIR/fails" 2>/dev/null || echo 0)
        fails=$((fails + 1))
        echo "$fails" > "$STATEDIR/fails"
        modem_log "data check FAIL ($fails/$FAIL_THRESHOLD) on $cur_op ($cur_plmn)"

        if [ "$fails" -ge "$FAIL_THRESHOLD" ]; then
            if [ "$cur_plmn" = "$PREFERRED" ] || [ -z "$cur_plmn" ]; then
                modem_log "fail threshold reached on preferred; initiating failover to fallback ($FALLBACK)"
                modem_switch "$FALLBACK"
            fi
        fi
        echo "FAIL"
        return 1
    fi
}

case "${0##*/}" in
    modem-supervisor.sh)
        case "$1" in
            status|--status) modem_status "$2" ;;
            decide|check|--check) modem_decide "$2" "$3" "$4" "$5" ;;
            switch) modem_switch "$2" "$3" ;;
            tick|once) modem_tick ;;
            *)
                echo "Usage: $0 {status [--json]|check <op> <tech> <rsrp> <rsrp5g>|switch <plmn>|tick}" >&2
                exit 1
                ;;
        esac
        ;;
esac
