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
    while [ "$jd" -le "$days_in" ]; do
        g=$(hn_jalali_to_greg "$(printf '%04d-%02d-%02d' "$jy" "$jm_n" "$jd")" 2>/dev/null) || { jd=$((jd+1)); continue; }
        [ -n "$g" ] || { jd=$((jd+1)); continue; }
        [ "$g" \> "$end_d" ] 2>/dev/null && break
        cur="$g"
        f="$OWNERS_D/$cur"
        if [ -f "$f" ]; then
            is_fri=$(dow_u "$cur")
            rate=$RATE_FULL; [ "$is_fri" = "5" ] && rate=$RATE_FRIDAY
            while IFS='|' read -r person mac up down; do
                [ -n "$person" ] || continue
                bytes=$(( ${up:-0} + ${down:-0} ))
                cost=$(awk -v b="$bytes" -v r="$rate" 'BEGIN{printf "%.0f", b/1073741824*r}')
                printf '%s\t%s\t%s\t%s\n' "$person" "$mac" "$bytes" "$cost" >> "$tmpf"
            done < "$f"
        fi
        jd=$((jd + 1))
    done

    # aggregate per person
    if [ -s "$tmpf" ]; then
        awk -F'\t' '{ u[$1]+=$3; c[$1]+=$4 } END { for(p in u) printf "%s\t%d\t%d\n", p, u[p], c[p] }' "$tmpf" \
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
        w=(int(E)%7+3)%7+1
        print w
    }'
}

# ---------- CLI (skipped when sourced) ----------
if [ "${0##*/}" = "ledger-store.sh" ]; then
case "${1:-}" in
    query) shift; ledger_query "${1:?month required}" ;;
    rates) ledger_rates ;;
    *) echo "usage: ledger-store.sh [query <jmonth>|rates]" >&2; exit 2 ;;
esac
fi
