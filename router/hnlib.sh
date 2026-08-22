#!/bin/sh
# hnlib.sh — the shared home-network business module.
#
# Canonical copy lives in this repo (router/hnlib.sh) and deploys to the router
# as /root/hnlib.sh. Each deep reader here is the one implementation of a rule
# the bot, the telemetry snapshot, the billing report and the Router API used
# to re-implement separately (with drifting regexes and rounding).
#
# Design: business readers take their inputs explicitly (path, rate — nothing is
# read from uci or the live router), so tests call them directly with fixtures.
# The system-state readers (hn_sys_*) are the one place that touches the live
# router; they are fixture-testable via env-configurable sources (HN_SYS_*) or
# function overrides.

# ── balance report ───────────────────────────────────────────────────────────

# hn_balance_fields [FILE] — parse the Samantel balance report text.
# stdout: key=value lines — available total plans quota remain pct expires days
# expired drain. available=0 when the file is missing or holds no report data
# (e.g. the transient "No data packages found." response); the other fields are
# empty when the report can't supply them.
hn_balance_fields() {
    local f="${1:-/tmp/balance_report}" text line2 avail=0
    [ -f "$f" ] || { echo "available=0"; return 0; }
    text=$(cat "$f" 2>/dev/null)
    line2=$(printf '%s\n' "$text" | sed -n '2p')
    [ -n "$line2" ] && avail=1
    printf 'available=%s\n' "$avail"
    printf 'total=%s\n'   "$(printf '%s\n' "$text" | sed -n '1{s/.* \([0-9.]*\) GB left across \([0-9]*\) plan.*/\1/p}')"
    printf 'plans=%s\n'   "$(printf '%s\n' "$text" | sed -n '1{s/.* \([0-9.]*\) GB left across \([0-9]*\) plan.*/\2/p}')"
    printf 'quota=%s\n'   "$(printf '%s\n' "$line2" | sed -n 's/Main: \([0-9]*\) GB.*/\1/p')"
    printf 'remain=%s\n'  "$(printf '%s\n' "$line2" | sed -n 's/Main: [0-9]* GB · \([0-9.]*\) GB left.*/\1/p')"
    printf 'pct=%s\n'     "$(printf '%s\n' "$line2" | sed -n 's/.*(\([0-9]*\)%).*/\1/p')"
    printf 'expires=%s\n' "$(printf '%s\n' "$line2" | sed -n 's/.*expires \([0-9-]*\) (.*/\1/p')"
    printf 'days=%s\n'    "$(printf '%s\n' "$line2" | sed -n 's/.*(\(~[0-9]*\)d).*/\1/p' | tr -dc '0-9')"
    printf 'expired=%s\n' "$(printf '%s\n' "$text" | sed -n 's/^+\([0-9]*\) expired plan.*/\1/p')"
    printf 'drain=%s\n'   "$(printf '%s\n' "$text" | sed -n 's/^Drain[[:space:]]*//p' | head -1 | sed 's/ (est.*//')"
}

# hn_balance_field <fields> <name> — extract one field from hn_balance_fields
# output. Callers never re-implement the sed extraction (botcmd, Router API).
hn_balance_field() {
    printf '%s\n' "$1" | sed -n "s/^$2=//p" | head -1
}

# hn_link_field <fields> <name> — extract one field from the X28 link-state
# output (the key=value lines from x28link.sh). One extractor for the bot,
# the Router API and the watchdog.
hn_link_field() {
    printf '%s\n' "$1" | sed -n "s/^$2=//p" | head -1
}

# hn_link_state [file] — deep LinkState seam: one reader for Link (operator
# / PLMN / tech / signal / RSRP / RSRP_5G / band / flow). Reads from the
# explicit file, or HN_LINK_STATE_FILE, or the live reader. Outputs 9
# key=value lines (empty if missing) so callers never re-parse.
hn_link_state() {
    local f="${1:-${HN_LINK_STATE_FILE:-}}"
    local fields=""
    if [ -n "$f" ] && [ -f "$f" ]; then
        fields=$(cat "$f" 2>/dev/null)
    elif [ -n "${HN_LINK_STATE_CMD:-}" ]; then
        fields=$($HN_LINK_STATE_CMD 2>/dev/null)
    else
        fields=$(cat /tmp/linkstate 2>/dev/null || sh /root/x28link.sh 2>/dev/null || true)
    fi
    local k v
    for k in operator plmn tech signal rsrp rsrp_5g band flow_dl flow_ul; do
        v=$(printf '%s\n' "$fields" | sed -n "s/^$k=//p" | head -1)
        printf '%s=%s\n' "$k" "${v:-}"
    done
}

# hn_link_decide <operator> <tech> <rsrp> <rsrp_5g> — pure LinkPolicy.
# Delegates to the same thresholds as x28w_decide (MCI drift, RSRP bad).
# Prints OK | FIX|operator | ALERT|degraded.
hn_link_decide() {
    local op="$1" rsrp="$3" rsrp5g="$4"
    local pref="${X28_PREF_OPERATOR:-MCI}"
    local bad="${X28_RSRP_BAD:--95}" bad5g="${X28_RSRP5G_BAD:--100}"
    case "$op" in *"$pref"*) : ;; *) echo "FIX|operator"; return 0 ;; esac
    if [ -n "$rsrp" ] && awk -v r="$rsrp" -v b="$bad" 'BEGIN{ exit !(r <= b) }'; then echo "ALERT|degraded"; return 0; fi
    if [ -n "$rsrp5g" ] && awk -v r="$rsrp5g" -v b="$bad5g" 'BEGIN{ exit !(r <= b) }'; then echo "ALERT|degraded"; return 0; fi
    echo "OK"
}

# hn_balance_series [days] [format] — balance history from the daily log,
# ascending (chronological), last `days` points. format: rows (date|gb lines,
# for the API history) or pipe (gb values joined by |, for the bot sparkline).
# Log dir configurable via HN_BALANCE_LOG_DIR so tests point it at fixtures.
hn_balance_series() {
    local days="${1:-90}" format="${2:-rows}" dir="${HN_BALANCE_LOG_DIR:-/etc/balance-log}"
    local rows
    rows=$(cat "$dir"/*.log 2>/dev/null |
        awk -F'|' '$1 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ && $2 ~ /[0-9]/ { print $1 "|" $2 }' |
        sort | tail -n "$days")
    if [ "$format" = "pipe" ]; then
        printf '%s\n' "$rows" | cut -d'|' -f2 | tr '\n' '|' | sed 's/|$//'
    else
        printf '%s\n' "$rows"
    fi
}

# ── cost table ───────────────────────────────────────────────────────────────

# hn_cost_table <rate> <round> — price "name|mac|bytes" rows from stdin.
# round is the configurable Toman tick (billing ROUND; the Router API used to
# hardcode 1000). stdout: one ROW|name|mac|gb|toman|share line per row (sorted
# by bytes descending) then a TOTAL|total_gb|total_toman line. share is the GB
# share, so the bot's text table and the Router API agree.
hn_cost_table() {
    local rate="${1:-7700}" round="${2:-1000}" tmp total_gb total_toman name mac bytes toman gb share
    # Guard against a non-numeric or empty ROUND (misconfigured billing.conf)
    case "$rate" in  *[!0-9]*) rate=7700  ;; esac
    case "$round" in *[!0-9]*) round=1000 ;; esac
    tmp=$(cat | while IFS='|' read -r name mac bytes; do
        [ -z "$name" ] && continue
        t=$(awk -v r="$rate" -v rnd="$round" -v b="${bytes:-0}" 'BEGIN{ print int(r*b/1073741824/rnd+0.5)*rnd }')
        g=$(awk -v b="${bytes:-0}" 'BEGIN{printf "%.4f", b/1073741824}')
        echo "$name|$mac|${bytes:-0}|$t|$g"
    done | sort -t'|' -k3 -rn)
    total_gb=$(printf '%s\n' "$tmp" | awk -F'|' '{g+=$3} END{printf "%.4f", g/1073741824}')
    total_toman=$(printf '%s\n' "$tmp" | awk -F'|' '{t+=$4} END{print t+0}')
    printf '%s\n' "$tmp" | while IFS='|' read -r name mac bytes toman gb; do
        [ -z "$name" ] && continue
        share=$(awk -v b="$bytes" -v t="$total_gb" 'BEGIN{ printf "%.1f", (t>0) ? (b/1073741824)/t*100 : 0 }')
        echo "ROW|$name|$mac|$gb|$toman|$share"
    done
    echo "TOTAL|$total_gb|$total_toman"
}

# ── system state ─────────────────────────────────────────────────────────────

# The deep reader behind "what is the router doing right now" — shared by the
# Router API (/status, /live), the bot dashboard, the hourly snapshot and the
# disk/reboot alerts. One implementation of each metric instead of four.
# The file-backed readers take the source file as an argument (fixture-friendly,
# same as hn_balance_fields); the command-backed readers are overridable as
# functions in tests (same trick the Router API tests use for ra_*).

# hn_sys_load [loadavg_file] — 1-min load average.
hn_sys_load() {
    awk '{print $1}' "${1:-${HN_SYS_LOADAVG:-/proc/loadavg}}" 2>/dev/null
}

# hn_sys_temp_c [thermal_file] — CPU temperature in °C (source is millidegrees).
hn_sys_temp_c() {
    awk '{printf "%d", $1/1000}' "${1:-${HN_SYS_THERMAL:-/sys/class/thermal/thermal_zone0/temp}}" 2>/dev/null
}

# hn_sys_mem — "used_mb total_mb" from free (BusyBox free ignores -m; compute from KB).
hn_sys_mem() {
    free | awk '/Mem:/{printf "%d %d", ($3>1024)?$3/1024:$3, ($2>1024)?$2/1024:$2}'
}

# hn_sys_disk — "pct|free" for the root filesystem.
hn_sys_disk() {
    df -h / | awk 'NR==2{gsub(/%/,"",$5); print $5"|"$4}'
}

# hn_sys_uptime — "3 days, 4:12".
hn_sys_uptime() {
    uptime | sed 's/.*up \([^,]*\),.*/\1/'
}

# hn_sys_proxy_state — "up|<latency_s>" or "down|" via the SOCKS 1070 204 probe.
# Sources configurable via env (HN_SYS_PROXY_SOCKS, HN_SYS_PROXY_URL, HN_SYS_PROXY_TIMEOUT).
hn_sys_proxy_state() {
    local out code t
    out=$(curl -sS -m "${HN_SYS_PROXY_TIMEOUT:-5}" --socks5 "${HN_SYS_PROXY_SOCKS:-127.0.0.1:1070}" -o /dev/null \
        -w '%{http_code}|%{time_total}' "${HN_SYS_PROXY_URL:-https://www.gstatic.com/generate_204}" 2>/dev/null)
    code=${out%%|*}; t=${out##*|}
    if [ "$code" = "204" ]; then echo "up|${t:-0}"; else echo "down|"; fi
}

# hn_sys_nlbw_total — total bytes across all devices (nlbwmon rx+tx sum).
# Binary configurable via HN_SYS_NLBW so tests point it at a fixture.
hn_sys_nlbw_total() {
    "${HN_SYS_NLBW:-/usr/sbin/nlbw}" -c json -g mac 2>/dev/null | jq -r '[.data[] | .[2] + .[4]] | add // 0'
}

# hn_sys_nlbw_macs — per-device nlbwmon rows as mac|rx|tx (for /live).
hn_sys_nlbw_macs() {
    "${HN_SYS_NLBW:-/usr/sbin/nlbw}" -c json -g mac 2>/dev/null | jq -r '.data[] | [.[0], .[2], .[4]] | @tsv' 2>/dev/null | tr '\t' '|'
}

# hn_sys_snapshot — all seven metrics as key=value lines (the hn_balance_fields shape).
hn_sys_snapshot() {
    echo "load=$(hn_sys_load)"
    echo "mem=$(hn_sys_mem)"
    echo "temp_c=$(hn_sys_temp_c)"
    echo "disk=$(hn_sys_disk)"
    echo "uptime=$(hn_sys_uptime)"
    echo "proxy=$(hn_sys_proxy_state)"
    echo "nlbw_total=$(hn_sys_nlbw_total)"
}
# hn_cooldown_ok <state_file> <cooldown_s> <action> — true when `action` is out
# of cooldown in <state_file>. The shared alert throttle for every degraded-* /
# alert-* path (speedtest, vpshealth, x28watch, quality alerts). A missing file
# or missing stamp counts as out of cooldown.
hn_cooldown_ok() {
    local state="$1" cd="$2" action="$3" now last
    now=$(date +%s)
    last=$(sed -n "s/^$action //p" "$state" 2>/dev/null | tail -1)
    [ -z "$last" ] && return 0
    [ $((now - last)) -ge "$cd" ]
}

# hn_cooldown_note <state_file> <action> — stamp `action` at now.
hn_cooldown_note() {
    local state="$1" action="$2"
    echo "$action $(date +%s)" >> "$state" 2>/dev/null
    tail -n 100 "$state" > "$state.tmp" 2>/dev/null && mv "$state.tmp" "$state" 2>/dev/null
}

# ---- link-quality module (the WAN edge's "how fast, right now") ----
# Probes assert aliveness; these functions assert quality. Distinguishes the
# cheap latency probe, the passive throughput derived from telemetry (no added
# bandwidth), and the targeted sample fired only on suspicion.

# hn_mbps_calc <bytes> <seconds> — pure; prints Mbps (the speedtest calc, here
# so the quality module and speedtest share one implementation).
hn_mbps_calc() {
    awk -v b="$1" -v t="$2" 'BEGIN{ if (t>0) printf "%.2f", b*8/t/1000000; else print 0 }'
}

# hn_q_latency — latency (s) through the active node via the SOCKS 204 probe.
# Prints the latency, or nothing when the proxy is down.
hn_q_latency() {
    hn_sys_proxy_state | awk -F'|' '$1=="up" && $2!="" { print $2 }'
}

# hn_q_passive_mbps <telemetry_log> — observed throughput from the last two
# hourly total_gb rows (free: no extra bandwidth). "0" when <2 rows. Honest
# limit: measures usage, so an idle hour reads low regardless of capacity.
hn_q_passive_mbps() {
    [ -f "$1" ] || { echo "0"; return; }
    awk -F'|' '
        $1 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/ && $2 ~ /^[0-9.]+$/ {
            t = $1 " 00"; gsub(/[-:]/," ",t); ep = mktime(t)
            if (ep <= 0 && prev_ts != "") ep = prev_ts + 3600   # busybox-awk fallback: hourly rows
            if (prev_ts != "" && ep > prev_ts) {
                dt = ep - prev_ts; dgb = $2 - prev_gb
                if (dgb > 0 && dt > 0) {
                    mbps = dgb * 8589934592 / dt / 1000000
                    last_mbps = mbps
                }
            }
            prev_ts = ep; prev_gb = $2
        }
        END { printf (last_mbps == "") ? "0" : "%.2f", (last_mbps == "") ? 0 : last_mbps }
    ' "$1" 2>/dev/null
}

# hn_telemetry_row <ts> <total_gb> <balance_gb> <proxy> <latency_s> <passive_mbps> <node>
# Pure hourly-row builder for the telemetry log. Existing fields come first so
# old `|`-splitting readers keep parsing; the quality fields trail.
hn_telemetry_row() {
    printf '%s|%s|%s|%s|%s|%s|%s\n' "$1" "$2" "$3" "$4" "${5:-0}" "${6:-0}" "${7:-}"
}

# hn_q_decision <latency_s> <sample_mbps> <floor_mbps> <lat_ceiling_s> — pure.
# Prints OK | ALERT|degraded. A usable sample below the floor is degraded; a
# bad latency catches it when the sample is unusable; unknown -> OK (aliveness
# is the failover chain's job, not the quality layer's).
hn_q_decision() {
    local lat="$1" sample="$2" floor="${3:-10}" ceiling="${4:-2.0}"
    if [ -n "$sample" ] && [ "$sample" != "0" ]; then
        if awk -v s="$sample" -v f="$floor" 'BEGIN{ exit (s >= f) ? 0 : 1 }'; then
            echo "OK"; return
        else
            echo "ALERT|degraded"; return
        fi
    fi
    if [ -n "$lat" ] && [ "$lat" != "0" ]; then
        if awk -v l="$lat" -v c="$ceiling" 'BEGIN{ exit (l <= c) ? 0 : 1 }'; then
            echo "OK"
        else
            echo "ALERT|degraded"
        fi
        return
    fi
    echo "OK"
}

# hn_q_suspicious <latency_s> <passive_mbps> <ceiling_s> <floor_mbps> — pure.
# The probing-budget rule: prints 1 (fire a bandwidth sample) only when a cheap
# signal suggests degradation — passive in (0, floor) means "used but slow",
# or latency at/over the ceiling. Idle hours (passive 0) are NOT suspicious.
hn_q_suspicious() {
    local lat="$1" passive="$2" ceiling="${3:-2.0}" floor="${4:-10}"
    if [ -n "$passive" ] && [ "$passive" != "0" ]; then
        if awk -v p="$passive" -v f="$floor" 'BEGIN{ exit (p < f) ? 0 : 1 }'; then
            echo "1"; return
        fi
    fi
    if [ -n "$lat" ] && [ "$lat" != "0" ]; then
        if awk -v l="$lat" -v c="$ceiling" 'BEGIN{ exit (l >= c) ? 0 : 1 }'; then
            echo "1"; return
        fi
    fi
    echo "0"
}

# hn_q_sample_mbps <mb> — targeted throughput sample (small download through
# Cloudflare). Prints Mbps or nothing on failure. The "spend bandwidth on
# suspicion" rung of the probing budget.
hn_q_sample_mbps() {
    local mb="${1:-10}" res size time
    res=$(curl -s -m 45 -o /dev/null -w '%{size_download}|%{time_total}' \
        "https://speed.cloudflare.com/__down?bytes=$((mb * 1000000))" 2>/dev/null)
    size=${res%%|*}; time=${res#*|}
    if [ -n "$size" ] && [ "$size" -gt 0 ] 2>/dev/null && [ -n "$time" ] && [ "$time" != "0" ]; then
        hn_mbps_calc "$size" "$time"
    fi
}

# hn_q_summary <telemetry_log> <floor_mbps> — the key=value quality block the
# telemetry snapshot and degraded alert read: latency, passive, sample,
# decision.
hn_q_summary() {
    local lat passive sample decision floor="${2:-10}"
    lat=$(hn_q_latency)
    passive=$(hn_q_passive_mbps "$1")
    sample=$(hn_q_sample_mbps)
    decision=$(hn_q_decision "$lat" "$sample" "$floor")
    echo "latency=${lat:-0}"
    echo "passive_mbps=$passive"
    echo "sample_mbps=${sample:-0}"
    echo "quality_decision=$decision"
}

# ---- cost forecast (burn-rate projection) ----
# hn_forecast_gb <gb_so_far> <days_elapsed> <days_in_month> — pure. Linear
# run-rate projection of month-end usage. 0 when nothing to extrapolate from.
hn_forecast_gb() {
    awk -v g="$1" -v e="$2" -v d="$3" 'BEGIN{ printf (e>0 && g>0) ? "%.2f" : "0", (e>0 && g>0) ? g*d/e : 0 }'
}

# hn_forecast_cost <gb_projected> <rate_toman_per_gb> — pure.
hn_forecast_cost() {
    awk -v g="$1" -v r="$2" 'BEGIN{ printf "%.0f", g*r }'
}

# hn_budget_decision <projected_toman> <budget_toman> — pure.
hn_budget_decision() {
    if awk -v p="$1" -v b="${2:-0}" 'BEGIN{ exit (p >= b && b > 0) ? 0 : 1 }'; then
        echo "ALERT|budget"
    else
        echo "OK"
    fi
}

# hn_budget_tier <remain_gb> <expiry_days> <projected_days> — pure tier.
# Defaults: warn <10 GB / <7d / proj<14d; urgent <3 GB / <3d / proj<7d; exhausted <0.05 GB.
# Empty values are treated as large (no alert). Prints one of: exhausted|urgent|warn|ok.
hn_budget_tier() {
    local remain="${1:-}" expiry="${2:-}" proj="${3:-}"
    # normalize empty to large sentinel
    [ -z "$remain" ] && remain=9999
    [ -z "$expiry" ] && expiry=9999
    [ -z "$proj" ] && proj=9999
    awk -v r="$remain" -v e="$expiry" -v p="$proj" '
    BEGIN{
        # exhausted first
        if (r+0 < 0.05) { print "exhausted"; exit }
        if (r+0 < 3 || e+0 < 3 || p+0 < 7) { print "urgent"; exit }
        if (r+0 < 10 || e+0 < 7 || p+0 < 14) { print "warn"; exit }
        print "ok"
    }'
}

# hn_days_until_friday <dow_1_7> — pure. Days until the Friday discount window
# (0 = today is Friday). dow uses `date +%u` (1=Mon..7=Sun).
hn_days_until_friday() {
    local dow="${1:-1}"
    echo $(( (5 - dow + 7) % 7 ))
}

# ---- Network Event log (the web dashboard's structured event feed) ----
# One shared recorder (hn_event_record) so every script records events in the
# same shape; the Router API /events endpoint reads through hn_event_list.
# Format (one line per event):
#   epoch|category|severity|kind|actor|message

HN_EVENT_LOG="${HN_EVENT_LOG:-/etc/network-events/events.log}"
HN_EVENT_MAX="${HN_EVENT_MAX:-2000}"

# hn_event_catalog — the event vocabulary: "kind|category|severity" lines.
# The catalog is the single source of event kinds; recording an event validates
# the kind against it and derives category+severity (callers never pass them).
hn_event_catalog() {
    cat <<'EOF'
internet_up|internet|info
internet_down|internet|critical
node_rotated|internet|warning
operator_reselected|internet|warning
quality_degraded|internet|warning
quality_recovered|internet|info
device_joined|device|info
device_blocked|device|warning
device_approved|device|info
proxy_changed|proxy|info
package_threshold|package|warning
router_rebooted|router|critical
dns_unhealthy|security|warning
EOF
}

# hn_event_meta <kind> — prints "category|severity" for a known kind, else "".
hn_event_meta() {
    hn_event_catalog | sed -n "s/^$1|/&/p" | head -1 | cut -d'|' -f2,3
}

# hn_event_record <kind> <message> [actor] — append one event. The kind is
# validated against the catalog; severity is derived, never passed.
hn_event_record() {
    local kind="$1" msg="$2" actor="${3:-system}" meta epoch
    meta=$(hn_event_meta "$kind")
    [ -n "$meta" ] || return 1
    mkdir -p "$(dirname "$HN_EVENT_LOG")" 2>/dev/null
    epoch=$(date +%s 2>/dev/null)
    [ -z "$epoch" ] && epoch=0
    [ -n "${HN_EVENT_TS:-}" ] && epoch=$HN_EVENT_TS   # test seam: deterministic timestamps
    printf '%s|%s|%s|%s|%s\n' "$epoch" "$meta" "$kind" "$actor" "$msg" >> "$HN_EVENT_LOG" 2>/dev/null
    # bound the log to HN_EVENT_MAX lines
    tail -n "$HN_EVENT_MAX" "$HN_EVENT_LOG" > "$HN_EVENT_LOG.tmp" 2>/dev/null &&
        mv "$HN_EVENT_LOG.tmp" "$HN_EVENT_LOG" 2>/dev/null
    return 0
}

# hn_event_list [limit] [category] — newest-first events (raw log lines).
hn_event_list() {
    local limit="${1:-50}" category="$2" filter
    if [ -n "$category" ]; then
        filter=$(grep "|$category|" "$HN_EVENT_LOG" 2>/dev/null)
    else
        filter=$(cat "$HN_EVENT_LOG" 2>/dev/null)
    fi
    printf '%s\n' "$filter" | grep -v '^$' | tail -n "$limit" | sort -t'|' -k1,1 -nr
}

# ---- Outage Ledger (X28 SLA) ----
# Append-only ledger for "no usable internet" periods. Ledger file is
# env-overridable via HN_OUTAGE_LEDGER for tests; format per line:
#   epoch|down  or  epoch|up
# Transitions are idempotent: consecutive downs overwrite, consecutive ups
# are ignored. Pairing is done on read; totals are per Jalali month via
# the calendar module. No new sensor — watchdog's direct-probe state drives it.

HN_OUTAGE_LEDGER="${HN_OUTAGE_LEDGER:-/data/proxy/outage-ledger.log}"

# hn_outage_pair <ledger_file> — completed down|up|duration lines, oldest first.
hn_outage_pair() {
    local f="${1:-$HN_OUTAGE_LEDGER}"
    [ -f "$f" ] || return 0
    sort -t'|' -k1,1 -n "$f" 2>/dev/null | awk -F'|' '
        $2=="down" { down=$1; next }
        $2=="up" && down!="" { print down"|"$1"|"($1-down); down="" }
    '
}

# hn_outage_format_duration <seconds> — human "3h40m" / "45m" / "0m".
hn_outage_format_duration() {
    local s="${1:-0}" h m
    s=$(( s + 0 )) 2>/dev/null || s=0
    [ "$s" -lt 0 ] && s=0
    h=$(( s / 3600 )); m=$(( (s % 3600) / 60 ))
    if [ "$h" -gt 0 ] && [ "$m" -gt 0 ]; then echo "${h}h${m}m"
    elif [ "$h" -gt 0 ]; then echo "${h}h"
    else echo "${m}m"
    fi
}

# hn_outage_total <ledger_file> <jalali_month> — total outage seconds in that Jalali month.
# Handles open down (no following up) as ongoing until now (HN_OUTAGE_NOW or date +%s).
hn_outage_total() {
    local f="${1:-$HN_OUTAGE_LEDGER}" jmonth="${2:-}" now start_d end_d start_e end_e_next total
    [ -f "$f" ] || { echo 0; return 0; }
    [ -n "$jmonth" ] || { echo 0; return 0; }
    # month range via calendar module
    local range
    range=$(hn_jalali_month_range "$jmonth" 2>/dev/null)
    [ -z "$range" ] && { echo 0; return 0; }
    start_d=$(printf '%s' "$range" | cut -d' ' -f1)
    end_d=$(printf '%s' "$range" | cut -d' ' -f2)
    [ -z "$start_d" ] || [ -z "$end_d" ] && { echo 0; return 0; }
    start_e=$(date -d "$start_d" +%s 2>/dev/null || date -d "$start_d 00:00:00" +%s 2>/dev/null || echo 0)
    end_e=$(date -d "$end_d" +%s 2>/dev/null || echo 0)
    end_e_next=$(( end_e + 86400 ))
    now=${HN_OUTAGE_NOW:-$(date +%s 2>/dev/null)}
    [ -z "$now" ] && now=0
    sort -t'|' -k1,1 -n "$f" 2>/dev/null | awk -F'|' -v ms="$start_e" -v me="$end_e_next" -v now="$now" '
        $2=="down" { down=$1; next }
        $2=="up" && down!="" {
            up=$1
            # overlap [down,up) with [ms,me)
            s = (down>ms?down:ms)
            e = (up<me?up:me)
            if(e>s) total+=e-s
            down=""
            next
        }
        END {
            if(down!=""){
                up=now
                s=(down>ms?down:ms)
                e=(up<me?up:me)
                if(e>s) total+=e-s
            }
            print total+0
        }
    '
}

# ---- service-health probe (the score's "services" component) ----
# Probes the router's subsystems without a new sensor: init-service state where
# the firmware exposes it, process probes otherwise (passwall). The probe
# function (hn_svc_running) is the test seam — tests override it with fixtures.
HN_SVC_LIST="${HN_SVC_LIST:-dnsmasq nlbwmon uhttpd odhcpd rpcd passwall adblock sqm}"

# hn_svc_running <svc> — 0 when the service is up. Overridable (tests), and
# command-backed (not file-backed) so it can't go stale.
hn_svc_running() {
    local svc="$1"
    case "$svc" in
        passwall) pgrep -f '/TCP.*SOCKS.json' >/dev/null 2>&1 ;;
        *) [ -x "/etc/init.d/$svc" ] && "/etc/init.d/$svc" running 2>/dev/null ;;
    esac
}

# hn_svc_probe [services] — "name=up|down" lines, one per service.
hn_svc_probe() {
    local list="${1:-$HN_SVC_LIST}" svc
    for svc in $list; do
        if hn_svc_running "$svc"; then echo "$svc=up"; else echo "$svc=down"; fi
    done
}

# hn_svc_down <probe> — the down-service names from hn_svc_probe output.
hn_svc_down() {
    printf '%s\n' "$1" | sed -n 's/=down$//p'
}

# hn_svc_penalty <down_count> — the score's service penalty: 5 per service,
# capped at the 20-weight (4 services fully eat the component).
hn_svc_penalty() {
    local n="${1:-0}" p
    p=$(( n * 5 ))
    [ "$p" -gt 20 ] && p=20
    echo "$p"
}

# ---- DNS health seam (the score's "dns" component) ----
# dnsmasq exposes its counters on SIGUSR1 (queries forwarded / answered
# locally, per-server retried-or-failed, average query time). hn_dns_stats
# parses that text; the API endpoint reads it via ra_dns_stats (overridable).

# hn_dns_success_rate <forwarded> <answered> <retried_failed> — pure.
# answered locally counts as success; retried-or-failed as failure. No queries
# at all -> 1 (nothing failed).
hn_dns_success_rate() {
    local f="${1:-0}" a="${2:-0}" r="${3:-0}" total good
    total=$((f + a)); good=$((total - r))
    awk -v t="$total" -v g="$good" 'BEGIN{ if (t > 0) printf "%.4f", g/t; else print 1 }'
}

# hn_dns_penalty <success_rate> <avg_latency_ms> — 0..15. Success below 98% is
# the full 15; latency over 200ms adds 8 (both capped at the 15 weight).
hn_dns_penalty() {
    local p=0
    awk -v s="${1:-1}" 'BEGIN{ if (s < 0.98) exit 1 }' && p=0 || p=15
    awk -v l="${2:-0}" 'BEGIN{ if (l > 200) exit 1 }' && : || p=$((p + 8))
    [ "$p" -gt 15 ] && p=15
    echo "$p"
}

# hn_dns_stats <text> — parse a dnsmasq SIGUSR1 dump. Prints the key=value block
# the health endpoint consumes: forwarded answered retried_failed avg_latency_ms.
hn_dns_stats() {
    local text="$1" f a r lat
    f=$(printf '%s\n' "$text" | sed -n 's/.*queries forwarded \([0-9]*\).*/\1/p' | head -1)
    a=$(printf '%s\n' "$text" | sed -n 's/.*queries answered locally \([0-9]*\).*/\1/p' | head -1)
    r=$(printf '%s\n' "$text" | sed -n 's/.*retried or failed \([0-9]*\).*/\1/p' | awk '{s+=$1} END{print s+0}')
    lat=$(printf '%s\n' "$text" | sed -n 's/.*avg time \([0-9]*\)ms.*/\1/p' | sort -n | tail -1)
    [ -z "$f" ] && f=0; [ -z "$a" ] && a=0; [ -z "$r" ] && r=0; [ -z "$lat" ] && lat=0
    echo "forwarded=$f"
    echo "answered=$a"
    echo "retried_failed=$r"
    echo "avg_latency_ms=$lat"
    echo "success_rate=$(hn_dns_success_rate "$f" "$a" "$r")"
}

# ---- Network Health Score (ADR-0005: derived, never a sensor) ----
# 100 minus per-component penalties. Weights: link 30, proxy 20, services 20,
# freshness 15, dns 15. The compute is pure; the /health endpoint gathers the
# raw signals and calls it.

# hn_health_link_penalty <quality_decision> — 30 when degraded (full weight).
# hn_q_decision prints "OK" or "ALERT|degraded"; anything with "degraded" is one.
hn_health_link_penalty() {
    case "$1" in
        *degraded*) echo 30 ;;
        *) echo 0 ;;
    esac
}

# hn_health_proxy_penalty <proxy_state> — 20 when down (full weight).
hn_health_proxy_penalty() {
    [ "$1" = "up" ] && echo 0 || echo 20
}

# hn_health_freshness_penalty <age_s> — stale telemetry: >10min -> 5, >60min -> 15.
hn_health_freshness_penalty() {
    local age="${1:-0}"
    [ "$age" -gt 3600 ] && { echo 15; return; }
    [ "$age" -gt 600 ] && { echo 5; return; }
    echo 0
}

# hn_health_score <link_pen> <proxy_pen> <svc_pen> <fresh_pen> <dns_pen> — pure.
hn_health_score() {
    local total=0
    total=$(( total + ${1:-0} + ${2:-0} + ${3:-0} + ${4:-0} + ${5:-0} ))
    [ "$total" -gt 100 ] && total=100
    [ "$total" -lt 0 ] && total=0
    echo $((100 - total))
}

# hn_health_band <score> — Excellent >=90, Good >=75, Degraded >=50, Poor <50.
hn_health_band() {
    local s="${1:-0}"
    [ "$s" -ge 90 ] && { echo Excellent; return; }
    [ "$s" -ge 75 ] && { echo Good; return; }
    [ "$s" -ge 50 ] && { echo Degraded; return; }
    echo Poor
}

# ---- Jalali calendar (Iranian) ----
# Pure Gregorian↔Jalali conversion (Behrooz, jalaali-js breaks table).
# All functions take explicit YYYY-MM-DD or YYYY-MM and echo the converted
# value; invalid input prints nothing and returns non-zero. No device calls.
# Implemented in awk so it runs on the router's busybox without python.

# hn_jalali_month_label <1..12> — Persian month name.
hn_jalali_month_label() {
    case "${1:-}" in
        1) echo "فروردین" ;;
        2) echo "اردیبهشت" ;;
        3) echo "خرداد" ;;
        4) echo "تیر" ;;
        5) echo "مرداد" ;;
        6) echo "شهریور" ;;
        7) echo "مهر" ;;
        8) echo "آبان" ;;
        9) echo "آذر" ;;
        10) echo "دی" ;;
        11) echo "بهمن" ;;
        12) echo "اسفند" ;;
        *) echo "" ; return 1 ;;
    esac
}

# hn_greg_to_jalali <YYYY-MM-DD> — Gregorian to Jalali, 04d-02d-02d.
hn_greg_to_jalali() {
    local in="$1" gy gm gd gm_n gd_n max
    case "$in" in ????-??-??) ;; *) echo ""; return 1 ;; esac
    gy=$(printf '%s' "$in" | cut -d- -f1)
    gm=$(printf '%s' "$in" | cut -d- -f2)
    gd=$(printf '%s' "$in" | cut -d- -f3)
    case "$gy" in *[!0-9]*) echo ""; return 1 ;; esac
    gm_n=$(printf '%s' "$gm" | sed 's/^0*//'); [ -z "$gm_n" ] && gm_n=0
    gd_n=$(printf '%s' "$gd" | sed 's/^0*//'); [ -z "$gd_n" ] && gd_n=0
    [ "$gm_n" -ge 1 ] 2>/dev/null && [ "$gm_n" -le 12 ] 2>/dev/null || { echo ""; return 1; }
    [ "$gd_n" -ge 1 ] 2>/dev/null && [ "$gd_n" -le 31 ] 2>/dev/null || { echo ""; return 1; }
    case "$gm_n" in
        1|3|5|7|8|10|12) max=31 ;;
        4|6|9|11) max=30 ;;
        2) if [ $((gy % 400)) -eq 0 ] || { [ $((gy % 4)) -eq 0 ] && [ $((gy % 100)) -ne 0 ]; }; then max=29; else max=28; fi ;;
    esac
    [ "$gd_n" -le "$max" ] 2>/dev/null || { echo ""; return 1; }
    awk -v gy="$gy" -v gm="$gm_n" -v gd="$gd_n" '
    function tdiv(a,b){return int(a/b)}
    function jmod(a,b){return a - tdiv(a,b)*b}
    function g2d(gy,gm,gd,  d){ d=tdiv((gy + tdiv(gm-8,6) + 100100)*1461,4)+tdiv(153*jmod(gm+9,12)+2,5)+gd-34840408; d=d-tdiv(tdiv(gy+100100+tdiv(gm-8,6),100)*3,4)+752; return d}
    function d2g(jdn,  j,i){ j=4*jdn+139361631; j=j+tdiv(tdiv(4*jdn+183187720,146097)*3,4)*4-3908; i=tdiv(jmod(j,1461),4)*5+308; D2G_GD=tdiv(jmod(i,153),5)+1; D2G_GM=jmod(tdiv(i,153),12)+1; D2G_GY=tdiv(j,1461)-100100+tdiv(8-D2G_GM,6) }
    function jalCal(jy,  _gy,_leapJ,_jp,_jm,_jump,_leap,_leapG,_march,_n,_i){ _gy=jy+621; _leapJ=-14; _jp=breaks[0]; _jump=0; for(_i=1;_i<bl;_i++){_jm=breaks[_i];_jump=_jm-_jp; if(jy < _jm) break; _leapJ=_leapJ+tdiv(_jump,33)*8+tdiv(jmod(_jump,33),4); _jp=_jm} _n=jy-_jp; _leapJ=_leapJ+tdiv(_n,33)*8+tdiv(jmod(_n,33)+3,4); if(jmod(_jump,33)==4 && _jump-_n==4) _leapJ++; _leapG=tdiv(_gy,4)-tdiv((tdiv(_gy,100)+1)*3,4)-150; _march=20+_leapJ-_leapG; if(_jump-_n<6) _n=_n-_jump+tdiv(_jump+4,33)*33; _leap=jmod(jmod(_n+1,33)-1,4); if(_leap==-1) _leap=4; JAL_LEAP=_leap; JAL_GY=_gy; JAL_MARCH=_march }
    function d2j(jdn,  _gy,_jy,_jdn1f,_k,_jm,_jd){ d2g(jdn); _gy=D2G_GY; _jy=_gy-621; jalCal(_jy); _jdn1f=g2d(_gy,3,JAL_MARCH); _k=jdn-_jdn1f; if(_k>=0){if(_k<=185){_jm=1+tdiv(_k,31);_jd=jmod(_k,31)+1; return _jy" "_jm" "_jd} else _k-=186} else {_jy--; _k+=179; if(JAL_LEAP==1) _k++} _jm=7+tdiv(_k,30); _jd=jmod(_k,30)+1; return _jy" "_jm" "_jd }
    BEGIN{
      breaks[0]=-61;breaks[1]=9;breaks[2]=38;breaks[3]=199;breaks[4]=426;breaks[5]=686;breaks[6]=756;breaks[7]=818;breaks[8]=1111;breaks[9]=1181;breaks[10]=1210;breaks[11]=1635;breaks[12]=2060;breaks[13]=2097;breaks[14]=2192;breaks[15]=2262;breaks[16]=2324;breaks[17]=2394;breaks[18]=2456;breaks[19]=3178; bl=20
      jdn=g2d(gy,gm,gd); res=d2j(jdn); split(res,r," "); printf "%04d-%02d-%02d\n", r[1], r[2], r[3]
    }' 2>/dev/null
}

# hn_jalali_to_greg <YYYY-MM-DD> — Jalali to Gregorian, 04d-02d-02d.
hn_jalali_to_greg() {
    local in="$1" jy jm jd jm_n jd_n max
    case "$in" in ????-??-??) ;; *) echo ""; return 1 ;; esac
    jy=$(printf '%s' "$in" | cut -d- -f1)
    jm=$(printf '%s' "$in" | cut -d- -f2)
    jd=$(printf '%s' "$in" | cut -d- -f3)
    case "$jy" in *[!0-9]*) echo ""; return 1 ;; esac
    jm_n=$(printf '%s' "$jm" | sed 's/^0*//'); [ -z "$jm_n" ] && jm_n=0
    jd_n=$(printf '%s' "$jd" | sed 's/^0*//'); [ -z "$jd_n" ] && jd_n=0
    [ "$jm_n" -ge 1 ] 2>/dev/null && [ "$jm_n" -le 12 ] 2>/dev/null || { echo ""; return 1; }
    [ "$jd_n" -ge 1 ] 2>/dev/null && [ "$jd_n" -le 31 ] 2>/dev/null || { echo ""; return 1; }
    case "$jm_n" in 1|2|3|4|5|6) max=31 ;; 7|8|9|10|11) max=30 ;; 12) max=30 ;; esac
    [ "$jd_n" -le "$max" ] 2>/dev/null || { echo ""; return 1; }
    awk -v jy="$jy" -v jm="$jm_n" -v jd="$jd_n" '
    function tdiv(a,b){return int(a/b)}
    function jmod(a,b){return a - tdiv(a,b)*b}
    function g2d(gy,gm,gd,  d){ d=tdiv((gy + tdiv(gm-8,6) + 100100)*1461,4)+tdiv(153*jmod(gm+9,12)+2,5)+gd-34840408; d=d-tdiv(tdiv(gy+100100+tdiv(gm-8,6),100)*3,4)+752; return d}
    function jalCal(jy,  _gy,_leapJ,_jp,_jm,_jump,_leap,_leapG,_march,_n,_i){ _gy=jy+621; _leapJ=-14; _jp=breaks[0]; _jump=0; for(_i=1;_i<bl;_i++){_jm=breaks[_i];_jump=_jm-_jp; if(jy < _jm) break; _leapJ=_leapJ+tdiv(_jump,33)*8+tdiv(jmod(_jump,33),4); _jp=_jm} _n=jy-_jp; _leapJ=_leapJ+tdiv(_n,33)*8+tdiv(jmod(_n,33)+3,4); if(jmod(_jump,33)==4 && _jump-_n==4) _leapJ++; _leapG=tdiv(_gy,4)-tdiv((tdiv(_gy,100)+1)*3,4)-150; _march=20+_leapJ-_leapG; if(_jump-_n<6) _n=_n-_jump+tdiv(_jump+4,33)*33; _leap=jmod(jmod(_n+1,33)-1,4); if(_leap==-1) _leap=4; JAL_LEAP=_leap; JAL_GY=_gy; JAL_MARCH=_march }
    function j2d(jy,jm,jd){ jalCal(jy); return g2d(JAL_GY,3,JAL_MARCH)+(jm-1)*31-tdiv(jm,7)*(jm-7)+jd-1 }
    function d2g(jdn,  j,i){ j=4*jdn+139361631; j=j+tdiv(tdiv(4*jdn+183187720,146097)*3,4)*4-3908; i=tdiv(jmod(j,1461),4)*5+308; D2G_GD=tdiv(jmod(i,153),5)+1; D2G_GM=jmod(tdiv(i,153),12)+1; D2G_GY=tdiv(j,1461)-100100+tdiv(8-D2G_GM,6) }
    BEGIN{
      breaks[0]=-61;breaks[1]=9;breaks[2]=38;breaks[3]=199;breaks[4]=426;breaks[5]=686;breaks[6]=756;breaks[7]=818;breaks[8]=1111;breaks[9]=1181;breaks[10]=1210;breaks[11]=1635;breaks[12]=2060;breaks[13]=2097;breaks[14]=2192;breaks[15]=2262;breaks[16]=2324;breaks[17]=2394;breaks[18]=2456;breaks[19]=3178; bl=20
      if(jm==12 && jd==30){ jalCal(jy); if(JAL_LEAP!=0) exit 1 }
      jdn=j2d(jy,jm,jd); d2g(jdn); printf "%04d-%02d-%02d\n", D2G_GY, D2G_GM, D2G_GD
    }' 2>/dev/null
    _rc=$?
    if [ $_rc -ne 0 ]; then echo ""; return 1; fi
}

# hn_jalali_month_range <YYYY-MM> — Jalali month to Gregorian start/end, "YYYY-MM-DD YYYY-MM-DD".
hn_jalali_month_range() {
    local in="$1" jy jm jm_n
    case "$in" in ????-??) ;; *) echo ""; return 1 ;; esac
    jy=$(printf '%s' "$in" | cut -d- -f1)
    jm=$(printf '%s' "$in" | cut -d- -f2)
    jm_n=$(printf '%s' "$jm" | sed 's/^0*//'); [ -z "$jm_n" ] && jm_n=0
    [ "$jm_n" -ge 1 ] 2>/dev/null && [ "$jm_n" -le 12 ] 2>/dev/null || { echo ""; return 1; }
    awk -v jy="$jy" -v jm="$jm_n" '
    function tdiv(a,b){return int(a/b)}
    function jmod(a,b){return a - tdiv(a,b)*b}
    function g2d(gy,gm,gd,  d){ d=tdiv((gy + tdiv(gm-8,6) + 100100)*1461,4)+tdiv(153*jmod(gm+9,12)+2,5)+gd-34840408; d=d-tdiv(tdiv(gy+100100+tdiv(gm-8,6),100)*3,4)+752; return d}
    function d2g(jdn,  j,i){ j=4*jdn+139361631; j=j+tdiv(tdiv(4*jdn+183187720,146097)*3,4)*4-3908; i=tdiv(jmod(j,1461),4)*5+308; D2G_GD=tdiv(jmod(i,153),5)+1; D2G_GM=jmod(tdiv(i,153),12)+1; D2G_GY=tdiv(j,1461)-100100+tdiv(8-D2G_GM,6) }
    function jalCal(jy,  _gy,_leapJ,_jp,_jm,_jump,_leap,_leapG,_march,_n,_i){ _gy=jy+621; _leapJ=-14; _jp=breaks[0]; _jump=0; for(_i=1;_i<bl;_i++){_jm=breaks[_i];_jump=_jm-_jp; if(jy < _jm) break; _leapJ=_leapJ+tdiv(_jump,33)*8+tdiv(jmod(_jump,33),4); _jp=_jm} _n=jy-_jp; _leapJ=_leapJ+tdiv(_n,33)*8+tdiv(jmod(_n,33)+3,4); if(jmod(_jump,33)==4 && _jump-_n==4) _leapJ++; _leapG=tdiv(_gy,4)-tdiv((tdiv(_gy,100)+1)*3,4)-150; _march=20+_leapJ-_leapG; if(_jump-_n<6) _n=_n-_jump+tdiv(_jump+4,33)*33; _leap=jmod(jmod(_n+1,33)-1,4); if(_leap==-1) _leap=4; JAL_LEAP=_leap; JAL_GY=_gy; JAL_MARCH=_march }
    function j2d(jy,jm,jd){ jalCal(jy); return g2d(JAL_GY,3,JAL_MARCH)+(jm-1)*31-tdiv(jm,7)*(jm-7)+jd-1 }
    BEGIN{
      breaks[0]=-61;breaks[1]=9;breaks[2]=38;breaks[3]=199;breaks[4]=426;breaks[5]=686;breaks[6]=756;breaks[7]=818;breaks[8]=1111;breaks[9]=1181;breaks[10]=1210;breaks[11]=1635;breaks[12]=2060;breaks[13]=2097;breaks[14]=2192;breaks[15]=2262;breaks[16]=2324;breaks[17]=2394;breaks[18]=2456;breaks[19]=3178; bl=20
      s_jdn=j2d(jy,jm,1)
      if(jm==12){ e_jdn=j2d(jy+1,1,1)-1 } else { e_jdn=j2d(jy,jm+1,1)-1 }
      d2g(s_jdn); printf "%04d-%02d-%02d ", D2G_GY,D2G_GM,D2G_GD; d2g(e_jdn); printf "%04d-%02d-%02d\n", D2G_GY,D2G_GM,D2G_GD
    }' 2>/dev/null
}

# ---- Owner (device → person) ----
# Owners file: lines "mac|person" (mac lowercased, person as-is). Env-overridable via HN_OWNERS_FILE.

HN_OWNERS_FILE="${HN_OWNERS_FILE:-/data/proxy/owners.conf}"

# hn_owner_of <mac> [owners_file] — person or empty. Mac lookup is case-insensitive.
hn_owner_of() {
    local mac="${1:-}" f="${2:-$HN_OWNERS_FILE}" want line
    [ -n "$mac" ] || { echo ""; return 0; }
    want=$(printf '%s' "$mac" | tr 'A-Z' 'a-z')
    [ -f "$f" ] || { echo ""; return 0; }
    line=$(grep -i "^$(printf '%s' "$want" | sed 's/[][\.*^$]/\\&/g')|" "$f" 2>/dev/null | head -1)
    [ -z "$line" ] && { echo ""; return 0; }
    printf '%s' "$line" | cut -d'|' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# ---- Boot doctor planner (post-boot convergence repair) ----
# hn_boot_repair_plan <health_gate_output> — pure. Reads the PASS/FAIL lines
# of x28-health.sh and prints the local repair actions, one per line, in a
# stable order: rules → dns → proxy → watchdog. Empty output = healthy boot,
# nothing to repair. Upstream failures (proxied_path alone, direct_path,
# v2raya) deliberately produce NO local repair — the watchdog/heal loops own
# those; restarting things locally would be noise.

# hn_boot_repair_plan <health_output>
hn_boot_repair_plan() {
    printf '%s\n' "$1" | sed -n 's/^FAIL //p' | awk '{print $1}' | sort -u | awk '
        {
            if      ($1 == "tproxy_chain" || $1 == "quic_block") r = 1
            else if ($1 == "dns_chain")                          d = 1
            else if ($1 == "xray_core")                          p = 1
            else if ($1 == "op_watchdog")                        w = 1
        }
        END {
            if (r) print "rules"
            if (d) print "dns"
            if (p) print "proxy"
            if (w) print "watchdog"
        }'
}

# ---- Maintenance window (auto-reboot decision) ----
# hn_maint_should_reboot <dow1_7> <hour> <uptime_days> <free_mb> [marker_cur] [marker_state]
# Pure. Reboot only inside the Sunday 05:00 window (dow=7, hour=5), once per
# window (marker_cur == marker_state blocks), and only when the box qualifies:
# uptime >= 14 days OR free RAM < 60 MB. Thresholds fixed by design; the
# caller derives dow/hour from device-local time and free_mb as KB-available.

# hn_maint_should_reboot <dow> <hour> <uptime_days> <free_mb> [mkcur] [mkstate]
hn_maint_should_reboot() {
    local dow="${1:-}" hr="${2:-}" up="${3:-0}" mb="${4:-999999}"
    local mkcur="${5:-}" mkstate="${6:-x}"
    [ "$dow" = "7" ] || { echo "wait"; return; }
    [ "$hr" = "5" ]  || { echo "wait"; return; }
    if [ -n "$mkcur" ] && [ "$mkcur" = "$mkstate" ]; then echo "wait"; return; fi
    case "$up" in *[!0-9]*) up=0 ;; esac
    case "$mb" in *[!0-9]*) mb=999999 ;; esac
    [ "$up" -ge 14 ] && { echo "reboot"; return; }
    [ "$mb" -lt 60 ] && { echo "reboot"; return; }
    echo "wait"
}

# hn_clock_skew_ok <local_epoch> <http_date_epoch> [max_skew_s] — pure.
# "ok" when |local - http| <= max (default 1800 s); empty input or unparsable
# values → "unknown" (caller decides fallback; maint treats unknown as ok but
# logs it).
hn_clock_skew_ok() {
    local loc="${1:-}" rem="${2:-}" maxs="${3:-1800}" d
    case "$loc" in ""|*[!0-9-]*) echo "unknown"; return ;; esac
    case "$rem" in ""|*[!0-9-]*) echo "unknown"; return ;; esac
    d=$(( loc - rem )); [ "$d" -lt 0 ] && d=$(( -d ))
    [ "$d" -le "$maxs" ] && { echo "ok"; return; }
    echo "skewed"
}

# hn_http_date_epoch "<Sun, 22 Aug 2026 20:48:19 GMT>" — pure. RFC1123 date
# header → unix epoch. Portable civil-date→epoch math in awk (no busybox -d);
# empty/unparsable input prints nothing.

# hn_http_date_epoch <header_value>
hn_http_date_epoch() {
    printf '%s\n' "${1:-}" | awk '
        function tdiv(a,b){ return int(a/b) }
        function jmod(a,b){ return a - tdiv(a,b)*b }
        {
            # expect: Wdy, DD Mon YYYY HH:MM:SS GMT
            dday=$2; mon=$3; yy=$4; t=$5
            if (dday !~ /^[0-9]+$/ || t !~ /^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]$/) next
            m = (mon=="Jan")?1:(mon=="Feb")?2:(mon=="Mar")?3:(mon=="Apr")?4:(mon=="May")?5:(mon=="Jun")?6:(mon=="Jul")?7:(mon=="Aug")?8:(mon=="Sep")?9:(mon=="Oct")?10:(mon=="Nov")?11:(mon=="Dec")?12:0
            if (m == 0) next
            split(t, T, ":")
            # proven Gregorian day-number math (same body as the Jalali g2d)
            dn = tdiv((yy + tdiv(m-8,6) + 100100)*1461, 4) + tdiv(153*jmod(m+9,12)+2, 5) + dday - 34840408
            dn = dn - tdiv(tdiv(yy + 100100 + tdiv(m-8,6), 100)*3, 4) + 752
            print (dn - 2440588) * 86400 + T[1]*3600 + T[2]*60 + T[3]
            exit
        }'
}

# ---- Config-drift classifier (nightly backup guard) ----
# hn_drift_classify <current.sha> <lastgood.sha> [pending.sha] — pure.
# Inputs are "sha256  path" lists. Prints one change line per difference —
# "M|path" (modified), "A|path" (added), "D|path" (deleted) — followed by a
# verdict line "V|CLEAN" | "V|SAME-AS-PENDING" (identical to the already-
# alerted set) | "V|ALERT". Last-good is NEVER advanced here; callers own
# acknowledge semantics so drift cannot be silently swallowed.

# hn_drift_classify <cur> <lastgood> [pending]
hn_drift_classify() {
    local _pend="${3:-/dev/null}"
    [ -f "$_pend" ] || _pend=/dev/null
    awk -v pend="$_pend" '
        FNR == 1 { idx++ }
        idx == 1 { cur[$2] = $1 }
        idx == 2 { lg[$2]  = $1 }
        idx == 3 { pd[$2]  = $1 }
        END {
            diff = 0
            for (p in cur) {
                if (!(p in lg))      { print "A|" p; diff = 1 }
                else if (cur[p] != lg[p]) { print "M|" p; diff = 1 }
            }
            for (p in lg) {
                if (!(p in cur))     { print "D|" p; diff = 1 }
            }
            if (!diff) { print "V|CLEAN"; exit }

            if (pend != "") {
                same = 1
                for (p in cur) if (pd[p] != cur[p]) same = 0
                for (p in pd)  if (!(p in cur))     same = 0
                if (same) { print "V|SAME-AS-PENDING"; exit }
            }
            print "V|ALERT"
        }
    ' "$1" "$2" "$_pend"
}

# ---- Bearer-bounce escalation (watchdog last rung) ----
# hn_bounce_decide <failed_rounds> <last_bounce_age_s> [after=2] [cooldown_s=3600]
# Pure. "yes" only when enough full switch-rounds have failed to restore
# data AND the previous bounce is outside its cooldown. The bounce itself is
# a forced re-registration on the current PLMN (cmd 228) — proven mechanics,
# not a new vendor surface.

# hn_bounce_decide <failed_rounds> <last_bounce_age_s> [after] [cooldown]
hn_bounce_decide() {
    local r="${1:-0}" age="${2:-999999}" after="${3:-2}" cd="${4:-3600}"
    case "$r"   in *[!0-9]*) r=0      ;; esac
    case "$age" in *[!0-9]*) age=999999 ;; esac
    [ "$r" -ge "$after" ] && [ "$age" -ge "$cd" ] && { echo "yes"; return; }
    echo "no"
}

# ---- Rescue supervisor decision (collected-node failover) ----
# hn_rescue_decide <dead_streak> <alive_streak> <world> <enabled> <rescue_alive> [promote_after] [demote_after]
# Pure. Prints "promote" | "demote" | "hold".
#   world=auto  & enabled & dead_streak>=4min-worth & rescue_alive>=1 -> promote
#   world=rescue & enabled & alive_streak>=10min-worth            -> demote
#   everything else -> hold. disabled flag forces eventual demotion via caller.

# hn_rescue_decide <dead> <alive> <world> <enabled> <ralive> [pa] [da]
hn_rescue_decide() {
    local d="${1:-0}" a="${2:-0}" w="${3:-auto}" en="${4:-1}" ra="${5:-0}"
    local pa="${6:-4}" da="${7:-10}"
    case "$d" in *[!0-9]*) d=0 ;; esac
    case "$a" in *[!0-9]*) a=0 ;; esac
    case "$ra" in *[!0-9]*) ra=0 ;; esac
    [ "$en" = "1" ] || { [ "$w" = "rescue" ] && { echo "demote"; return; }; echo "hold"; return; }
    if [ "$w" = "auto" ]; then
        [ "$d" -ge "$pa" ] && [ "$ra" -ge 1 ] && { echo "promote"; return; }
    elif [ "$w" = "rescue" ]; then
        [ "$a" -ge "$da" ] && { echo "demote"; return; }
    fi
    echo "hold"
}

# ---- quality-history rollup (the hourly link-quality chart feed) ----
# The hourly telemetry rows already carry the quality fields (latency,
# passive_mbps, node) — this reader rolls them into the chart series the
# dashboard's quality card consumes, without a new collector.

# hn_quality_series [telemetry_log] [hours] — "ts|latency|passive_mbps|node"
# rows, oldest first, from the last `hours` hourly samples.
hn_quality_series() {
    local log="${1:-${HN_TELEMETRY_LOG:-/etc/telemetry/hourly.log}}" hours="${2:-24}" n
    n=$(( hours * 1 ))
    [ "$n" -lt 1 ] 2>/dev/null && n=24
    awk -F'|' '$1 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/ { print $1 "|" $5 "|" $6 "|" $7 }' "$log" 2>/dev/null |
        tail -n "$n"
}
