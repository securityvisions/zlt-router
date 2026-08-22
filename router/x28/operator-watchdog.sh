#!/bin/sh
# operator-watchdog.sh — automatic cellular operator failover for the ZLT X28.
#
# Problem: MCI (43211, fast 5G at night) sometimes loses data connectivity for
# hours (daytime congestion). The vendor web UI has no usable operator switch.
# This watchdog monitors real data connectivity and switches operators
# automatically:
#   - data dead on MCI  -> switch to Rightel (fallback) after N failures
#   - healthy on Rightel -> probe MCI periodically (with backoff), return
#     automatically once MCI data works again
#
# SAFETY: it NEVER uses the PLMN lock (cmd 219) that previously wedged the
# modem. It only uses the vendor's own select call (cmd 228 via reselect.sh,
# the same call the web UI's select button makes), proven to work in both
# directions. Storm guard + cooldown prevent switch flapping.
#
# Usage:
#   operator-watchdog.sh            run the daemon loop
#   operator-watchdog.sh once       single check cycle (no switching)
#   operator-watchdog.sh switch X   one operator switch to PLMN X
# Env:
#   WATCHDOG_DRYRUN=1               log decisions, never switch
# Logs: /data/proxy/watchdog.log

PREFERRED="${WATCHDOG_PREFERRED:-43211}"     # MCI (5G, fast)
FALLBACK="${WATCHDOG_FALLBACK:-43220}"       # Rightel (4G, reliable)
ACT="${WATCHDOG_ACT:-13}"
CHECK_INTERVAL="${WATCHDOG_INTERVAL:-60}"    # seconds between checks (60s: outage-to-switch ~3min)
FAIL_THRESHOLD="${WATCHDOG_FAILS:-3}"        # consecutive fails before switch
PROBE_MIN="${WATCHDOG_PROBE_MIN:-2700}"      # min secs between preferred probes (45m)
PROBE_MAX="${WATCHDOG_PROBE_MAX:-10800}"     # probe backoff cap (3h)
COOLDOWN="${WATCHDOG_COOLDOWN:-600}"         # no-switch window after a switch
MAX_PER_HOUR="${WATCHDOG_MAX_H:-3}"          # switch storm guard
BOUNCE_AFTER="${WATCHDOG_BOUNCE_AFTER:-2}"   # failed switch-rounds before bearer bounce
BOUNCE_COOLDOWN="${WATCHDOG_BOUNCE_COOLDOWN:-3600}"  # min secs between bounces
WAN_BOUNCE_DRYRUN="${WATCHDOG_WAN_BOUNCE_DRYRUN:-0}" # 1 = log the bounce, never act

LOG=/data/proxy/watchdog.log
STATEDIR=/tmp/x28-watchdog
ENDPOINTS="${WATCHDOG_ENDPOINTS:-https://1.1.1.1 https://216.239.38.120}"

# hnlib: bounce decision + outage ledger hooks (best-effort source)
for _hnl in /data/proxy/hnlib.sh /root/hnlib.sh; do [ -f "$_hnl" ] && . "$_hnl" && break; done

mkdir -p "$STATEDIR"

now() { date +%s; }
trimlog() {
    [ -f "$LOG" ] || return 0
    n=$(wc -l < "$LOG" 2>/dev/null)
    [ -n "$n" ] && [ "$n" -gt 400 ] && tail -n 300 "$LOG" > "$LOG.t" 2>/dev/null && mv "$LOG.t" "$LOG"
    return 0
}
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"; trimlog; }

# notify <title> <body> — best-effort Telegram alert. tg-notify never blocks
# or fails (own timeout, own error swallowing), so the watchdog loop is safe.
notify() {
    sh /data/proxy/tg-notify.sh "$1" "$2" >/dev/null 2>&1 || true
}
# opname <plmn> — human operator name for alerts.
opname() {
    case "$1" in
        "$PREFERRED") echo "MCI (preferred)" ;;
        "$FALLBACK")  echo "Rightel (fallback)" ;;
        *)            echo "${1:-unknown}" ;;
    esac
}

# check_data: true if any endpoint answers HTTPS by IP (no DNS involved)
check_data() {
    for ep in $ENDPOINTS; do
        code=$(curl -k -s -m 8 -o /dev/null -w '%{http_code}' "$ep" 2>/dev/null)
        case "$code" in 200|204|301|302) return 0 ;; esac
    done
    return 1
}

# cur_plmn: current operator as PLMN code (43211/43220), "" if unknown
cur_plmn() {
    out=$(timeout 20 sh /data/proxy/linkstate.sh 2>/dev/null)
    p=$(printf '%s' "$out" | sed -n 's/^plmn=//p' | head -1)
    if [ -n "$p" ]; then echo "$p"; return 0; fi
    op=$(printf '%s' "$out" | sed -n 's/^operator=//p' | head -1)
    case "$op" in
        *MCI*)    echo "$PREFERRED" ;;
        *Rightel*) echo "$FALLBACK" ;;
        *)        echo "" ;;
    esac
}

switches_last_hour() {
    t=$(now); c=0
    for f in "$STATEDIR"/sw.*; do
        [ -f "$f" ] || continue
        ts=${f##*sw.}
        [ $((t - ts)) -lt 3600 ] && c=$((c + 1))
    done
    echo "$c"
}

record_switch() {
    : > "$STATEDIR/sw.$(now)"
    t=$(now)
    for f in "$STATEDIR"/sw.*; do
        [ -f "$f" ] || continue
        ts=${f##*sw.}
        [ $((t - ts)) -gt 7200 ] && rm -f "$f"
    done
}

# do_switch <plmn>: switch operator, wait for data, re-apply clean DNS
do_switch() {
    target="$1"
    if [ "$WATCHDOG_DRYRUN" = 1 ]; then
        log "DRYRUN: would switch to $target"
        return 1
    fi
    n=$(switches_last_hour)
    if [ "$n" -ge "$MAX_PER_HOUR" ]; then
        log "switch to $target SKIPPED: $n switches in last hour (storm guard)"
        return 1
    fi
    log "switching operator -> $target"
    resp=$(X28_TARGET_PLMN="$target" X28_TARGET_ACT="$ACT" timeout 100 sh /data/proxy/reselect.sh 2>&1 | tail -n1)
    log "reselect: $resp"
    record_switch
    echo "$(now)" > "$STATEDIR/lastswitch"
    i=0
    while [ $i -lt 8 ]; do
        sleep 15
        if check_data; then
            sh /data/proxy/dns-fix.sh >/dev/null 2>&1 || true
            log "switch to $target OK: data confirmed"
            notify "Operator switch to $(opname "$target") — data confirmed" \
                   "$(sh /data/proxy/x28-status.sh 2>/dev/null | sed -n '1,3p')"
            return 0
        fi
        i=$((i + 1))
    done
    sh /data/proxy/dns-fix.sh >/dev/null 2>&1 || true
    log "switch to $target done but data still down after wait"
    notify "Switch to $(opname "$target") — data still down" \
           "The switch ran but data is not confirmed yet; the watchdog keeps monitoring."
    return 1
}

# do_bounce <plmn> — escalation rung: forced re-registration on the CURRENT
# operator (same proven cmd 228 path as a switch, but without the already-on
# shortcut) — this is what unsticks a wedged data bearer. Ledgered + notified;
# WAN_BOUNCE_DRYRUN=1 logs the decision and never acts.
do_bounce() {
    cur="$1"
    if [ "$WAN_BOUNCE_DRYRUN" = "1" ] || [ "$WATCHDOG_DRYRUN" = "1" ]; then
        log "DRYRUN: would bounce bearer (forced re-register on $cur)"
        return 0
    fi
    log "escalation: bouncing bearer via forced re-register on $cur"
    echo "$(now)" > "$STATEDIR/last-bounce"
    sh /data/proxy/x28-outage-ledger.sh add-down 2>/dev/null || true
    resp=$(X28_TARGET_PLMN="$cur" X28_TARGET_ACT="$ACT" timeout 100 sh /data/proxy/reselect.sh 2>&1 | tail -n1)
    log "bounce reselect: $resp"
    i=0
    while [ $i -lt 8 ]; do
        sleep 15
        if check_data; then
            sh /data/proxy/dns-fix.sh >/dev/null 2>&1 || true
            sh /data/proxy/x28-outage-ledger.sh add-up 2>/dev/null || true
            log "bearer bounce OK: data restored"
            notify "🔄 Bearer bounced — data restored" \
                   "Switches failed $ROUNDS_FAILED round(s); forced re-register on $(opname "$cur") recovered the data plane."
            return 0
        fi
        i=$((i + 1))
    done
    log "bearer bounce done but data still down"
    notify "🔄 Bearer bounced — still down" \
           "Forced re-register on $(opname "$cur") did not restore data; watchdog keeps monitoring."
    return 1
}

# ---- one-shot modes ----
cmd="$1"
if [ "$cmd" = "switch" ] && [ -n "$2" ]; then
    do_switch "$2"
    exit $?
fi
if [ "$cmd" = "bounce" ]; then
    cur="$(cur_plmn)"; [ -z "$cur" ] && cur="$PREFERRED"
    do_bounce "$cur"
    exit $?
fi
if [ "$cmd" = "once" ]; then
    d=DOWN; check_data && d=OK
    echo "plmn=$(cur_plmn) data=$d"
    log "once: plmn=$(cur_plmn) data=$d"
    exit 0
fi

# ---- daemon ----
fails=0
ROUNDS_FAILED=0
last_probe=0
probe_delay=$PROBE_MIN
echo "$(now)" > "$STATEDIR/lastswitch"
log "watchdog started (preferred=$PREFERRED fallback=$FALLBACK interval=${CHECK_INTERVAL}s threshold=$FAIL_THRESHOLD bounce_after=$BOUNCE_AFTER dryrun=${WATCHDOG_DRYRUN:-0})"

while :; do
    sleep "$CHECK_INTERVAL"
    # DNS-path guard: dns-fix probes the tunnel and keeps dnsmasq's upstream
    # matched to reality (tunnel vs ISP fallback). No-op when already correct.
    sh /data/proxy/dns-fix.sh >/dev/null 2>&1 || true
    p=$(cur_plmn)
    if check_data; then
        if [ "$fails" -gt 0 ]; then
            log "plmn=$p data OK (recovered after $fails fails)"
            sh /data/proxy/x28-outage-ledger.sh add-up 2>/dev/null || true
            notify "Data recovered - $(opname "$p")" \
                   "Back online after $fails failed checks.
$(sh /data/proxy/x28-status.sh 2>/dev/null | sed -n '1,3p')"
        fi
        fails=0
        ROUNDS_FAILED=0
        echo "$(now)" > "$STATEDIR/lastdata"
        if [ "$p" = "$FALLBACK" ]; then
            t=$(now); lp=$(cat "$STATEDIR/lastswitch" 2>/dev/null || echo 0)
            if [ $((t - lp)) -gt "$COOLDOWN" ] && [ $((t - last_probe)) -gt "$probe_delay" ]; then
                last_probe=$t
                log "probing preferred $PREFERRED"
                if do_switch "$PREFERRED"; then
                    probe_delay=$PROBE_MIN
                else
                    probe_delay=$((probe_delay * 2))
                    [ "$probe_delay" -gt "$PROBE_MAX" ] && probe_delay=$PROBE_MAX
                    log "preferred not usable; next probe in $((probe_delay / 60))m; returning to fallback"
                    notify "MCI probe failed - staying on Rightel" \
                           "Preferred operator not usable yet; next probe in $((probe_delay / 60))m."
                    do_switch "$FALLBACK" || true
                fi
            fi
        fi
    else
        fails=$((fails + 1))
        log "plmn=$p data DOWN (fail $fails/$FAIL_THRESHOLD)"
        if [ "$fails" -eq "$FAIL_THRESHOLD" ]; then
            sh /data/proxy/x28-outage-ledger.sh add-down 2>/dev/null || true
        fi
        if [ "$fails" -ge "$FAIL_THRESHOLD" ]; then
            t=$(now); lp=$(cat "$STATEDIR/lastswitch" 2>/dev/null || echo 0)
            if [ $((t - lp)) -lt "$COOLDOWN" ]; then
                log "cooldown active ($((t - lp))s since last switch) - waiting"
                # Escalation rung: switches keep failing to restore data →
                # bounce the bearer itself (forced re-register, own cooldown).
                lb=$(cat "$STATEDIR/last-bounce" 2>/dev/null || echo 0)
                age=$((t - lb))
                case "$age" in *[!0-9]*) age=999999 ;; esac
                if [ "$(hn_bounce_decide "$ROUNDS_FAILED" "$age" "$BOUNCE_AFTER" "$BOUNCE_COOLDOWN")" = "yes" ]; then
                    target="$p"
                    [ -z "$target" ] && target="$PREFERRED"
                    do_bounce "$target"
                    ROUNDS_FAILED=0
                fi
            else
                if [ "$p" = "$PREFERRED" ] || [ -z "$p" ]; then
                    do_switch "$FALLBACK"; rc=$?
                else
                    do_switch "$PREFERRED"; rc=$?
                fi
                if [ "$rc" = "0" ]; then
                    ROUNDS_FAILED=0
                else
                    ROUNDS_FAILED=$((ROUNDS_FAILED + 1))
                    log "switch round failed ($ROUNDS_FAILED consecutive) — escalation ladder armed"
                fi
                fails=0
            fi
        fi
    fi
done
