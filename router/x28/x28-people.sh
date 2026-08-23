#!/bin/sh
# x28-people.sh — household Ledger: per-person usage for a Jalali month.
#
# Output modes:
#   (default)          plain text  — alerts / digest
#   --html [month]     HTML card   — bot (/people · /month · Panel)
#   --freeze <month>   write the rendered page to ledger/J-<month>.txt
#
# Data: owners-d/YYYY-MM-DD rows (person|mac|up|down) via ledger-store.
# Env seams: USAGE_DIR, HN_OWNERS_FILE, HN_LIB, PEOPLE_TODAY.
set -eu

USAGE_DIR="${USAGE_DIR:-/data/proxy/usage}"
LEDGER_DIR="${LEDGER_DIR:-$USAGE_DIR/ledger}"
HN_LIB="${HN_LIB:-/root/hnlib.sh}"
[ -f "$HN_LIB" ] || HN_LIB="/data/proxy/hnlib.sh"
[ -f "$HN_LIB" ] || HN_LIB="$(dirname "$0")/../hnlib.sh"
[ -f "$HN_LIB" ] && . "$HN_LIB" 2>/dev/null || true

# source the shared Ledger store (day-walk + rates + aggregation)
for _ls in "$(dirname "$0")/ledger-store.sh" "/data/proxy/usage/ledger-store.sh"; do
    [ -f "$_ls" ] && . "$_ls" && break
done 2>/dev/null

RATE_FULL="${RATE_FULL:-7700}"
RATE_FRIDAY="${RATE_FRIDAY:-4620}"
[ -r "$USAGE_DIR/billing.conf" ] && . "$USAGE_DIR/billing.conf" 2>/dev/null || true

esc() { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }
bar() { awk -v p="${1:-0}" -v w="${2:-10}" 'BEGIN{
    f=int(p*w/100+0.5); if(f>w)f=w; if(f<0)f=0;
    for(i=0;i<w;i++){ if(i<f) s=s "▰"; else s=s "▱" } print s}'; }

mode="text"; jmonth=""

# ── daily mode: single day ──────────────────────────────────────────────────
if [ "${1:-}" = "--daily" ]; then
    ddate="${2:?date required}"
    OWNERS_D="${USAGE_DIR:-/data/proxy/usage}/owners-d"
    f="$OWNERS_D/$ddate"
    if [ ! -f "$f" ]; then echo "(no data for $ddate)"; exit 0; fi
    [ -r "$USAGE_DIR/billing.conf" ] && . "$USAGE_DIR/billing.conf" 2>/dev/null || true
    RATE_FULL="${RATE_FULL:-7700}"; RATE_FRIDAY="${RATE_FRIDAY:-4620}"
    is_fri=$(date -d "$ddate" +%u 2>/dev/null || echo 1)
    rate=$RATE_FULL; [ "$is_fri" = "5" ] && rate=$RATE_FRIDAY
    echo "📅 Daily — $ddate"
    echo "person        GB      Toman"
    while IFS='|' read -r person mac up down; do
        bytes=$(( ${up:-0} + ${down:-0} )); [ $bytes -le 0 ] && continue
        cost=$(awk -v b="$bytes" -v r="$rate" 'BEGIN{printf "%.0f", b/1073741824*r}')
        gb=$(awk -v b=$bytes 'BEGIN{printf "%.2f",b/1073741824}')
        printf '%-12s %7s GB %9d T\n' "${person:-?}" "$gb" "$cost"
    done < "$f" | sort -t'#' -k1
    exit 0
fi

# ── yearly mode: aggregate all months in a Jalali year ────────────────────
if [ "${1:-}" = "--yearly" ]; then
    jyear="${2:?Jalali year required (e.g. 1405)}"
    OWNERS_D="${USAGE_DIR:-/data/proxy/usage}/owners-d"
    AGGY=$(mktemp); : > "$AGGY"
    for m in $(seq 1 12); do
        mj=$(printf '%04d-%02d' "$jyear" "$m")
        mr=$(hn_jalali_month_range "$mj" 2>/dev/null) || continue
        [ -z "$mr" ] && continue
        ms=$(echo "$mr"|cut -d' ' -f1); me=$(echo "$mr"|cut -d' ' -f2)
        cd2="$ms"
        while [ -n "$cd2" ]; do
            [ "$cd2" \> "$me" ] 2>/dev/null && break
            f="$OWNERS_D/$cd2"
            if [ -f "$f" ]; then
                while IFS='|' read -r person mac up down; do
                    [ -n "$person" ]||continue; bytes=$(( ${up:-0}+${down:-0} ))
                    printf '%s|%s|%s\n' "$person" "$bytes" "$(( bytes * RATE_FULL / 1073741824 ))" >> "$AGGY"
                done < "$f"
            fi
            cd2=$(hn_jalali_to_greg "$(hn_greg_to_jalali "$cd2" | awk -F- '{jd=$3+1;printf "%04d-%02d-%02d",$1,$2,jd}')" 2>/dev/null) || break
            [ -z "$cd2" ] && break
        done
    done
    if [ -s "$AGGY" ]; then
        echo "📅 Yearly — $jyear"
        echo "person        GB      Toman"
        sort "$AGGY" | awk -F'|' '{u[$1]+=$2;c[$1]+=$3}
            END{for(p in u) printf "%-12s %7.2f GB %9d T\n",p,u[p]/1073741824,c[p]}'
    else
        echo "(no data for year $jyear)"
    fi
    rm -f "$AGGY"; exit 0
fi

mode="text"; jmonth=""
case "${1:-}" in
    --html)  mode="html"; jmonth="${2:-}" ;;
    --freeze) mode="freeze"; jmonth="${2:?month required}" ;;
    --daily)  mode="daily"; jmonth="${2:?date required (YYYY-MM-DD)}" ;;
    --yearly) mode="yearly"; jmonth="${2:?Jalali year required (YYYY)}" ;;
    *)       jmonth="${1:-}" ;;
esac

if [ -z "$jmonth" ]; then
    greg_today=${PEOPLE_TODAY:-$(date +%F 2>/dev/null)}
    jmonth=$(hn_greg_to_jalali "$greg_today" 2>/dev/null | cut -d- -f1,2 || true)
fi
case "$jmonth" in ????-??) ;; *) echo "Invalid Jalali month: ${jmonth:-none}" >&2; exit 1 ;; esac

range=$(hn_jalali_month_range "$jmonth" 2>/dev/null || true)
if [ -z "$range" ]; then echo "Invalid Jalali month: $jmonth" >&2; exit 1; fi
start_d=$(printf '%s' "$range" | cut -d' ' -f1)
end_d=$(printf '%s' "$range" | cut -d' ' -f2)

today=${PEOPLE_TODAY:-$(date +%F 2>/dev/null)}
if [ -n "$today" ] && [ "$start_d" \> "$today" ] 2>/dev/null; then :
elif [ -n "$today" ] && [ "$end_d" \> "$today" ] 2>/dev/null; then end_d="$today"; fi

jy=$(printf '%s' "$jmonth" | cut -d- -f1)
jm_n=$(printf '%s' "$jmonth" | cut -d- -f2 | sed 's/^0*//')
label=$(hn_jalali_month_label "$jm_n" 2>/dev/null || echo "")
days_in=$(awk -v s="$start_d" -v e="$end_d" 'BEGIN{
    "date -d " s " +%s" | getline se; close("date -d " s " +%s")
    "date -d " e " +%s" | getline ee; close("date -d " e " +%s")
    print int((ee-se)/86400)+1 }' 2>/dev/null || echo "?")

# ---- aggregate via ledger-store ----
LS_SCRIPT="$(dirname "$0")/ledger-store.sh"
[ -f "$LS_SCRIPT" ] || LS_SCRIPT="/data/proxy/usage/ledger-store.sh"

AGG=$(mktemp)
trap 'rm -f "$AGG"' EXIT

# run the store's query in a subshell with correct env
sh "$LS_SCRIPT" query "$jmonth" > "$AGG" 2>/dev/null || {
    # fallback: inline walk using hnlib directly
    : > "$AGG"
    start_j="$jy-$jm_n-01"
    jd=1
    [ "$days_in" = "?" ] 2>/dev/null && days_in=31
    while [ "$jd" -le "$days_in" ]; do
        g=$(hn_jalali_to_greg "$(printf '%04d-%02d-%02d' "$jy" "$jm_n" "$jd")" 2>/dev/null) || { jd=$((jd+1)); continue; }
        [ -n "$g" ] || { jd=$((jd+1)); continue; }
        [ "$g" \> "$end_d" ] 2>/dev/null && break
        f="$OWNERS_D/$cur"
        f="$USAGE_DIR/owners-d/$g"
        if [ -f "$f" ]; then
            is_fri=$(dow_u "$g" 2>/dev/null || echo 1)
            rate=$RATE_FULL; [ "$is_fri" = "5" ] && rate=$RATE_FRIDAY
            while IFS='|' read -r person mac up down; do
                [ -n "$person" ] || continue
                bytes=$(( ${up:-0} + ${down:-0} ))
                cost=$(awk -v b="$bytes" -v r="$rate" 'BEGIN{printf "%.0f", b/1073741824*r}')
                printf '%s\t%s\t%s\t%s\n' "$person" "$mac" "$bytes" "$cost" >> "$AGG"
            done < "$f"
        fi
        jd=$((jd + 1))
    done
}

no_data() {
    if [ "$mode" = "html" ]; then
        printf '<b>👥 دفتر %s %s</b> · %s روز · <i>%s … %s</i>\n' "$(esc "$label")" "$(esc "$jy")" "$(esc "$days_in")" "$(esc "$start_d")" "$(esc "$end_d")"
    else
        printf '👥 People — %s (%s)\nrange %s to %s\n(no usage data for this month yet)\n' "$jmonth" "${label:-}" "$start_d" "$end_d"
    fi
    return 0
}

# yearly mode: aggregate all months in the Jalali year
if [ "$mode" = "yearly" ]; then
    : > "$AGG"
    for m in $(seq 1 12); do
        mj=$(printf '%04d-%02d' "$jy" "$m")
        mr=$(hn_jalali_month_range "$mj" 2>/dev/null) || continue
        [ -z "$mr" ] && continue
        ms=$(printf '%s' "$mr" | cut -d' ' -f1)
        me=$(printf '%s' "$mr" | cut -d' ' -f2)
        cd2="$ms"
        while [ -n "$cd2" ]; do
            [ "$cd2" \> "$me" ] 2>/dev/null && break
            f="$OWNERS_D/$cd2"
            if [ -f "$f" ]; then
                while IFS='|' read -r person mac up down; do
                    [ -n "$person" ] || continue
                    bytes=$(( ${up:-0} + ${down:-0} ))
                    cost=$(awk -v b="$bytes" -v r="$RATE_FULL" 'BEGIN{printf "%.0f", b/1073741824*r}')
                    printf '%s\t%s\t%s\t%s\n' "$person" "$mac" "$bytes" "$cost" >> "$AGG.tmp"
                done < "$f"
            fi
            cd2=$(hn_jalali_to_greg "$(hn_greg_to_jalali "$cd2" | awk -F- '{jd=$3+1; printf "%04d-%02d-%02d",$1,$2,jd}')" 2>/dev/null) || break
            [ -z "$cd2" ] && break
        done
    done
    if [ -s "${AGG}.tmp" ]; then
        awk -F'\t' '{u[$1]+=$2;c[$1]+=$3}
            END{for(p in u) printf "%s\t%d\t%d\n",p,u[p],c[p]}' "${AGG}.tmp" > "$AGG"
        rm -f "${AGG}.tmp"
    fi
    # override label for yearly display
    label="سال $jy"
fi

if [ ! -s "$AGG" ]; then no_data; [ "$mode" = "freeze" ] && exit 1; exit 0; fi

total_bytes=$(cut -f2 "$AGG" | awk '{s+=$1} END{print s+0}')
total_cost=$(cut -f3 "$AGG" | awk '{s+=$1} END{print s+0}')
total_gb=$(awk -v b="$total_bytes" 'BEGIN{printf "%.1f", b/1073741824}')

hdr() {
    if [ "$mode" = "html" ]; then
        printf '<b>👥 دفتر %s %s</b> · %s روز · <i>%s … %s</i>\n' "$(esc "$label")" "$(esc "$jy")" "$(esc "$days_in")" "$(esc "$start_d")" "$(esc "$end_d")"
    else
        printf '👥 People — %s (%s)\nrange %s to %s\n' "$jmonth" "$label" "$start_d" "$end_d"
    fi
    return 0
}
hdr

max_bytes=$(cut -f2 "$AGG" | sort -n | tail -1)

render_html() { printf '%s <code>%s</code>  %.1f GB · %s T · %s%%\n' \
    "$(esc "$1")" "$(bar "$4" 10)" "$(awk -v b="$2" 'BEGIN{printf "%.1f", b/1073741824}')" \
    "$(printf "%'d" "$3" 2>/dev/null || echo "$3")" "$4"; }
render_text() { printf '%-12s %7s GB %9d T\n' "$1" \
    "$(awk -v b="$2" 'BEGIN{printf "%.2f", b/1073741824}')" "$3"; }

while IFS="$(printf '\t')" read -r person bytes cost; do
    [ "${bytes:-0}" -gt 0 ] 2>/dev/null || continue
    pct=0; [ "$max_bytes" -gt 0 ] 2>/dev/null && pct=$(( bytes * 100 / max_bytes ))
    if [ "$mode" = "html" ]; then render_html "$person" "$bytes" "$cost" "$pct"
    else render_text "$person" "$bytes" "$cost"; fi
done < "$AGG"

if [ "$mode" = "html" ]; then
    echo "<i>total <b>${total_gb} GB</b> · $(printf "%'d" "$total_cost" 2>/dev/null || echo "$total_cost") Toman</i>"
else
    total_gb=$(awk -v b="$total_bytes" 'BEGIN{printf "%.2f", b/1073741824}')
    printf '%-12s %7s GB %9d T\n' "TOTAL" "$total_gb" "$total_cost"
fi

# ---- per-device breakdown (HTML only) ----
if [ "$mode" = "html" ]; then
    echo ""
    echo "<blockquote expandable>"
    jd=1
    while [ "$jd" -le "$days_in" ]; do
        g=$(hn_jalali_to_greg "$(printf '%04d-%02d-%02d' "$jy" "$jm_n" "$jd")" 2>/dev/null) || { jd=$((jd+1)); continue; }
        [ -n "$g" ] || { jd=$((jd+1)); continue; }
        [ "$g" \> "$end_d" ] 2>/dev/null && break
        f="$OWNERS_D/$g"
        if [ -f "$f" ]; then
            while IFS='|' read -r person mac up down; do
                case "$mac" in [0-9A-Fa-f][0-9A-Fa-f]:*) ;; *) continue ;; esac
                bytes=$(( ${up:-0} + ${down:-0} ))
                [ "${bytes:-0}" -gt 0 ] || continue
                gb=$(awk -v b="$bytes" 'BEGIN{printf "%.1f", b/1073741824}')
                printf '%s · <code>%s</code> · %s GB\n' "$(esc "$person")" "$(esc "$mac")" "$gb"
            done < "$f"
        fi
        jd=$((jd + 1))
    done
    echo "</blockquote>"
fi

exit 0
