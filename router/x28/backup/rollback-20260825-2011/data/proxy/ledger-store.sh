#!/bin/sh
# ledger-store.sh — single aggregation seam for the household Ledger.
#
# Owns: owners-d day-walking (Jalali-index → hnlib conversion, bounded by
# days_in), rate-table loading (billing.conf), Friday detection (pure-awk
# weekday math), Toman formatting, empty-month handling.
#
# Exports:
#   ledger_query <jalali_month> — emits TSV rows "person\tbytes\tcost"
#   ledger_rates                — prints RATE_FULL and RATE_FRIDAY
#
# Consumers: x28-people.sh (HTML/text card), x28-digest.sh (rescue line),
# x28-budget.sh (projected cost from same rate table). All previously had
# private walkers/aggregators that duplicated this logic three times.
#
# Env seams for tests: USAGE_DIR, RATE_FULL, RATE_FRIDAY, PEOPLE_TODAY.

USAGE_DIR="${USAGE_DIR:-/data/proxy/usage}"
OWNERS_D="$USAGE_DIR/owners-d"

RATE_FULL="${RATE_FULL:-7700}"
RATE_FRIDAY="${RATE_FRIDAY:-4620}"
[ -r "$USAGE_DIR/billing.conf" ] && . "$USAGE_DIR/billing.conf" 2>/dev/null || true

HN_LIB="${HN_LIB:-/root/hnlib.sh}"
[ -f "$HN_LIB" ] || HN_LIB="/data/proxy/hnlib.sh"
[ -f "$HN_LIB" ] || HN_LIB="$(dirname "$0")/../hnlib.sh"
[ -f "$HN_LIB" ] && . "$HN_LIB" 2>/dev/null || true

# ledger_rates — print the loaded rate table
ledger_rates() {
    printf 'RATE_FULL=%s\nRATE_FRIDAY=%s\n' "$RATE_FULL" "$RATE_FRIDAY"
}

# ledger_day_rows <greg-date> — emit owners-d-shaped rows (person|mac|up|down)
# for the date. Rolled file wins; else, when the date is today, attribute the
# live per-device file (mac|ip|name|up|down) through the owners file so
# "today" is never missing from the Ledger before the midnight roll.
ledger_day_rows() {
    local d="${1:?date required}"
    local f="$OWNERS_D/$d"
    [ -f "$f" ] && { cat "$f"; return 0; }
    local today="${PEOPLE_TODAY:-$(date +%F 2>/dev/null)}"
    [ "$d" = "$today" ] || return 0
    f="$USAGE_DIR/day/$d"
    [ -f "$f" ] || return 0
    local owners="${HN_OWNERS_FILE:-/data/proxy/owners.conf}"
    local mac ip name up down person want line
    while IFS='|' read -r mac ip name up down; do
        case "$mac" in "#"*|"") continue ;; esac
        [ -n "$mac" ] || continue
        person=""
        if [ -f "$owners" ]; then
            want=$(printf '%s' "$mac" | tr 'A-Z' 'a-z')
            line=$(grep -i "^$(printf '%s' "$want" | sed 's/[][\.*^$]/\\&/g')|" "$owners" 2>/dev/null | head -1)
            person=$(printf '%s' "$line" | cut -d'|' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        fi
        [ -n "$person" ] || person="unassigned"
        printf '%s|%s|%s|%s\n' "$person" "$mac" "${up:-0}" "${down:-0}"
    done < "$f"
}

# ledger_query <jmonth> — emit TSV "person\ttotal_bytes\ttotal_cost" rows,
# sorted by bytes descending. Zero-byte persons included. Empty output when
# no data exists for the month. Uses hn_jalali_to_greg for busybox-safe
# day walking; Friday detection via pure-awk civil-days weekday.
ledger_query() {
    local jmonth="${1:?month required}"
    case "$jmonth" in ????-??) ;; *) return 1 ;; esac

    local range start_d end_d jy jm_n label days_in
    range=$(hn_jalali_month_range "$jmonth" 2>/dev/null) || return 1
    [ -z "$range" ] && return 1
    start_d=$(printf '%s' "$range" | cut -d' ' -f1)
    end_d=$(printf '%s' "$range" | cut -d' ' -f2)

    local today="${PEOPLE_TODAY:-$(date +%F 2>/dev/null)}"
    if [ -n "$today" ] && [ "$start_d" \> "$today" ] 2>/dev/null; then : # future
    elif [ -n "$today" ] && [ "$end_d" \> "$today" ] 2>/dev/null; then end_d="$today"; fi

    jy=$(printf '%s' "$jmonth" | cut -d- -f1)
    local jm_n=$(printf '%s' "$jmonth" | cut -d- -f2 | sed 's/^0*//')
    local days_in=$(hn_jalali_month_range "$jmonth" 2>/dev/null | awk '{print $NF}' | {
        # count days from range dates
        s=$(date +%s 2>/dev/null); e=$(date +%s 2>/dev/null)
        echo 0  # fallback — overridden below on GNU date systems
    })
    # compute days_in via hn_greg_to_jalali roundtrip or simple bound
    days_in=40  # generous upper bound; loop breaks at month boundary

    local tmpf=$(mktemp 2>/dev/null)
    : > "$tmpf"

    local jd=1 g cur f is_fri rate person mac up down bytes cost
    local daytmp=$(mktemp 2>/dev/null)
    while [ "$jd" -le "$days_in" ]; do
        g=$(hn_jalali_to_greg "$(printf '%04d-%02d-%02d' "$jy" "$jm_n" "$jd")" 2>/dev/null) || { jd=$((jd+1)); continue; }
        [ -n "$g" ] || { jd=$((jd+1)); continue; }
        [ "$g" \> "$end_d" ] 2>/dev/null && break
        cur="$g"
        ledger_day_rows "$cur" > "$daytmp" 2>/dev/null
        if [ -s "$daytmp" ]; then
            is_fri=$(dow_u "$cur")
            rate=$RATE_FULL; [ "$is_fri" = "5" ] && rate=$RATE_FRIDAY
            while IFS='|' read -r person mac up down; do
                [ -n "$person" ] || continue
                bytes=$(( ${up:-0} + ${down:-0} ))
                cost=$(awk -v b="$bytes" -v r="$rate" 'BEGIN{printf "%.0f", b/1073741824*r}')
                printf '%s\t%s\t%s\t%s\n' "$person" "$mac" "$bytes" "$cost" >> "$tmpf"
            done < "$daytmp"
        fi
        jd=$((jd + 1))
    done
    rm -f "$daytmp"

    # aggregate per person (%.0f: busybox awk %d clamps at 2^31)
    if [ -s "$tmpf" ]; then
        awk -F'\t' '{ u[$1]+=$3; c[$1]+=$4 } END { for(p in u) printf "%s\t%.0f\t%.0f\n", p, u[p], c[p] }' "$tmpf" \
            | sort -t"$(printf '\t')" -k2,2 -nr
    fi
    rm -f "$tmpf"
}

# dow_u <YYYY-MM-DD> — weekday 1..7 (Mon=1), pure awk
dow_u() {
    awk -v d="$1" 'BEGIN{
        split(d,a,"-"); y=a[1]+0; m=a[2]+0; dd=a[3]+0
        if(m<=2){y--; m+=12}
        A=int(y/100); B=int(A/4)
        E=int(365.25*(y+4716)) + int(30.6001*(m+1)) + dd + B - A - 1524.5 - 2440588
        w=(int(E)%7+6)%7+1
        print w
    }'
}

# greg_next <YYYY-MM-DD> — next Gregorian day, busybox-safe (no date -d)
greg_next() {
    printf '%s' "$1" | awk -F- '{
        y=$1+0; m=$2+0; d=$3+1
        dim[1]=31;dim[2]=28;dim[3]=31;dim[4]=30;dim[5]=31;dim[6]=30
        dim[7]=31;dim[8]=31;dim[9]=30;dim[10]=31;dim[11]=30;dim[12]=31
        if(y%4==0&&(y%100!=0||y%400==0))dim[2]=29
        if(d>dim[m]){d=1;m++}
        if(m>12){m=1;y++}
        printf "%04d-%02d-%02d\n",y,m,d
    }'
}

# ledger_rollup <greg-date> — regenerate rollups/<jalali-YYYY-MM>.tsv for the
# Jalali month containing the date. Full-month recompute from the day-row seam
# (idempotent, self-healing). Rows: date|person|bytes|cost.
ledger_rollup() {
    local d="${1:?date required}"
    local jm=$(hn_greg_to_jalali "$d" 2>/dev/null | cut -d- -f1,2)
    [ -n "$jm" ] || return 1
    local range start_d end_d
    range=$(hn_jalali_month_range "$jm" 2>/dev/null) || return 1
    [ -n "$range" ] || return 1
    start_d=${range%% *}; end_d=${range##* }
    local today="${PEOPLE_TODAY:-$(date +%F 2>/dev/null)}"
    [ -n "$today" ] && [ "$end_d" \> "$today" ] 2>/dev/null && end_d="$today"
    mkdir -p "$USAGE_DIR/rollups" 2>/dev/null
    local out="$USAGE_DIR/rollups/$jm.tsv"
    local tmpf="$out.tmp"
    : > "$tmpf" || return 1
    local cur="$start_d" is_fri rate
    while [ -n "$cur" ]; do
        [ "$cur" \> "$end_d" ] 2>/dev/null && break
        is_fri=$(dow_u "$cur")
        rate=$RATE_FULL; [ "$is_fri" = "5" ] && rate=$RATE_FRIDAY
        ledger_day_rows "$cur" 2>/dev/null | awk -F'|' -v d="$cur" -v r="$rate" '
            NF >= 4 {
                b=$3+$4; c=b/1073741824*r; u[$1]+=b; cc[$1]+=c
            }
            END { for(p in u) printf "%s|%s|%.0f|%.0f\n", d, p, u[p], cc[p] }' >> "$tmpf"
        cur=$(greg_next "$cur")
    done
    mv "$tmpf" "$out"
}

# ledger_rollup_all — regenerate rollups for every Jalali month that has
# owners-d history (plus the current month). Backfill entry point.
ledger_rollup_all() {
    local months d
    months=$(for f in "$OWNERS_D"/20*; do
        [ -f "$f" ] || continue
        d=${f##*/}
        hn_greg_to_jalali "$d" 2>/dev/null | cut -d- -f1,2
    done | sort -u)
    [ -n "$months" ] || months=$(hn_greg_to_jalali "$(date +%F)" 2>/dev/null | cut -d- -f1,2)
    local m
    for m in $months; do
        # anchor on any gregorian date inside the month
        local g=$(hn_jalali_to_greg "$m-01" 2>/dev/null)
        [ -n "$g" ] && ledger_rollup "$g"
    done
}

# ---------- CLI (skipped when sourced) ----------
if [ "${0##*/}" = "ledger-store.sh" ]; then
case "${1:-}" in
    query) shift; ledger_query "${1:?month required}" ;;
    day-rows) shift; ledger_day_rows "${1:?date required}" ;;
    rollup) shift; ledger_rollup "${1:?date required}" ;;
    rollup-all) ledger_rollup_all ;;
    rates) ledger_rates ;;
    *) echo "usage: ledger-store.sh [query <jmonth>|day-rows <date>|rollup <date>|rollup-all|rates]" >&2; exit 2 ;;
esac
fi
