#!/bin/sh
# x28-owner-backfill.sh — one-shot: convert historical per-device day-files
# into device-granularity owner rollups (owners-d/YYYY-MM-DD).
#
# Day-file line : mac|ip|name|up|down
# Rollup line   : person|mac|up|down        (person via owners.conf; unknown
#                                            MACs -> "unassigned")
# Idempotent: a date is converted only if owners-d/<date> is absent, so
# reruns and nightly-roll files coexist safely.
#
# Modes:
#   run              — scan the whole day-dir (default)
#   date <YYYY-MM-DD> — convert a single day file (test seam)
# Env seams: DAY_DIR, OWNERS_D, HN_OWNERS_FILE, HN_LIB
set -u

DAY_DIR="${DAY_DIR:-/data/proxy/usage/day}"
OWNERS_D="${OWNERS_D:-/data/proxy/usage/owners-d}"
HN_OWNERS_FILE="${HN_OWNERS_FILE:-/data/proxy/owners.conf}"
HN_LIB="${HN_LIB:-/root/hnlib.sh}"
[ -f "$HN_LIB" ] || HN_LIB="/data/proxy/hnlib.sh"
[ -f "$HN_LIB" ] && . "$HN_LIB" 2>/dev/null || true

mkdir -p "$OWNERS_D" 2>/dev/null

owner_of() {
    if command -v hn_owner_of >/dev/null 2>&1; then
        hn_owner_of "$1" "$HN_OWNERS_FILE" 2>/dev/null
    else
        want=$(printf '%s' "$1" | tr 'A-Z' 'a-z')
        grep -i "^$(printf '%s' "$want" | sed 's/[][\.*^$]/\\&/g')|" "$HN_OWNERS_FILE" 2>/dev/null \
            | head -1 | cut -d'|' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    fi
}

convert_day() {  # convert_day <date> -> rows written count
    local date="$1"
    local src="$DAY_DIR/$date"
    local dst="$OWNERS_D/$date"
    [ -f "$src" ] || { echo 0; return 0; }
    [ -f "$dst" ] && { echo 0; return 0; }   # idempotent: never rewrite
    tmp="$dst.tmp"
    : > "$tmp"
    while IFS='|' read -r mac ip name up down; do
        case "$mac" in '#'*|"") continue ;; esac
        person=$(owner_of "$mac")
        [ -z "$person" ] && person="unassigned"
        printf '%s|%s|%s|%s\n' "$person" "$mac" "${up:-0}" "${down:-0}" >> "$tmp"
    done < "$src"
    mv "$tmp" "$dst"
    echo "$(wc -l < "$dst")"
}

case "${1:-run}" in
    date) convert_day "${2:?date required}" ;;
    run)
        total_days=0; total_rows=0
        for f in "$DAY_DIR"/20*; do
            [ -f "$f" ] || continue
            d=${f##*/}
            case "$d" in *.tmp|*.new) continue ;; esac
            r=$(convert_day "$d")
            if [ "${r:-0}" -gt 0 ]; then
                total_days=$((total_days+1)); total_rows=$((total_rows+r))
                echo "backfilled $d ($r rows)"
            fi
        done
        echo "summary: days=$total_days rows=$total_rows"
        ;;
    *) echo "usage: x28-owner-backfill.sh [run|date YYYY-MM-DD]" >&2; exit 2 ;;
esac
