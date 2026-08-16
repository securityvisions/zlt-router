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
