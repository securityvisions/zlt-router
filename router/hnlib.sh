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
            if (prev_ts != "" && ep > prev_ts && ep != -1) {
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
