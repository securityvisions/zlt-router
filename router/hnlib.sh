#!/bin/sh
# hnlib.sh — the shared home-network business module.
#
# Canonical copy lives in this repo (router/hnlib.sh) and deploys to the router
# as /root/hnlib.sh. Each deep reader here is the one implementation of a rule
# the bot, the telemetry snapshot, the billing report and the Router API used
# to re-implement separately (with drifting regexes and rounding).
#
# Design: every function takes its inputs explicitly (path, rate — nothing is
# read from uci or the live router), so tests call them directly with fixtures.
# This module touches no router state by itself.

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