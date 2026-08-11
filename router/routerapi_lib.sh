#!/bin/sh
# routerapi_lib.sh — pure JSON builders for the Xirouter Router API.
#
# Canonical copy lives in this repo (router/routerapi_lib.sh); it is deployed to
# /www/cgi-bin/routerapi_lib.sh next to the routerapi.sh CGI dispatcher.
#
# Design: the state-reading functions below (ra_load, ra_mem, ra_usage_today, ...)
# are the seam — the CGI runs them against real router state, tests override them
# with fixtures and assert the JSON. The builders never touch router state directly.
#
# Paths are configurable via env (defaults are the router layout) so tests can point
# them at fixtures:
#   RA_CONF /etc/routerapp.conf        TOKEN=...
#   RA_USAGE_LOG_DIR /etc/usage-log    baseline + monthly logs + user-names + watchlist
#   RA_BALANCE_LOG_DIR /etc/balance-log
#   RA_TELEMETRY_LOG /etc/telemetry/hourly.log
#   RA_DHCP_LEASES /tmp/dhcp.leases
#   RA_BALANCE_REPORT /tmp/balance_report       RA_BALANCE_REPORT_TS /tmp/balance_report.ts
#   RA_BILLING_CONF /etc/billing.conf
#   RA_USAGE_SH /root/usage.sh
#   RA_NODES  "name|uci-id" lines (known proxy nodes)
#   RA_EXCLUDED_MACS  space-separated router MACs to hide from device lists

RA_CONF="${RA_CONF:-/etc/routerapp.conf}"
RA_USAGE_LOG_DIR="${RA_USAGE_LOG_DIR:-/etc/usage-log}"
RA_BALANCE_LOG_DIR="${RA_BALANCE_LOG_DIR:-/etc/balance-log}"
RA_TELEMETRY_LOG="${RA_TELEMETRY_LOG:-/etc/telemetry/hourly.log}"
RA_DHCP_LEASES="${RA_DHCP_LEASES:-/tmp/dhcp.leases}"
RA_BALANCE_REPORT="${RA_BALANCE_REPORT:-/tmp/balance_report}"
RA_BALANCE_REPORT_TS="${RA_BALANCE_REPORT_TS:-/tmp/balance_report.ts}"
RA_USER_NAMES="${RA_USER_NAMES:-$RA_USAGE_LOG_DIR/user-names}"
RA_WATCHLIST="${RA_WATCHLIST:-$RA_USAGE_LOG_DIR/watchlist}"
RA_BILLING_CONF="${RA_BILLING_CONF:-/etc/billing.conf}"
RA_USAGE_SH="${RA_USAGE_SH:-/root/usage.sh}"
RA_EXCLUDED_MACS="${RA_EXCLUDED_MACS:-}"
RA_NODES="${RA_NODES:-$(uci show passwall 2>/dev/null | sed -n "s/^passwall\.\([^@.][^.]*\)\.remarks='\([^']*\)'/\2|\1/p")}"
[ -n "$RA_NODES" ] || RA_NODES='REALITY-443-parsa|skReality
hysteria2|skWrAzdt'
DIV=1073741824

# ---------- tiny JSON helpers ----------
ra_esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
ra_ts()  { date +%s; }

ra_conf_val() {  # <file> <key>
    sed -n "s/^$2=\"\?\([^\" ]*\)\"\?$/\1/p" "$1" 2>/dev/null | head -1
}

ra_is_excluded_mac() {  # <mac>
    case "$1" in
        ff:ff:ff:ff:ff:ff|01:00:5e:*) return 0 ;;
    esac
    [ -n "$RA_EXCLUDED_MACS" ] && echo "$RA_EXCLUDED_MACS" | grep -qw "$1" && return 0
    return 1
}

ra_name_for_key() {  # <key> — custom name from user-names, else ""
    sed -n "s/^$1[[:space:]]\+\(.*\)/\1/p" "$RA_USER_NAMES" 2>/dev/null | head -1
}

# ---------- auth ----------
# The token rides the standard HTTP Authorization header (Basic auth; the token
# is the password, username ignored) because uhttpd does not forward custom
# X-* headers to CGI. The legacy X-Router-Token header is still accepted for
# back-compat and in-shell tests.
ra_authed() {
    local want decoded
    want=$(sed -n 's/^TOKEN=//p' "$RA_CONF" 2>/dev/null | head -1 | tr -d '"' | tr -d ' ')
    [ -n "$want" ] || return 1
    if [ -n "$HTTP_X_ROUTER_TOKEN" ] && [ "$HTTP_X_ROUTER_TOKEN" = "$want" ]; then
        return 0
    fi
    case "$HTTP_AUTHORIZATION" in
        Basic*|basic*)
            decoded=$(printf '%s' "${HTTP_AUTHORIZATION#* }" | base64 -d 2>/dev/null)
            [ "$decoded" = "$want" ] && return 0
            case "$decoded" in *:*) [ "${decoded#*:}" = "$want" ] && return 0 ;; esac
            ;;
    esac
    return 1
}

# ---------- state functions (the test seam; router defaults here) ----------
ra_load()        { awk '{print $1}' /proc/loadavg 2>/dev/null; }
ra_mem()         { free | awk '/Mem:/{printf "%d %d", ($3>1024)?$3/1024:$3, ($2>1024)?$2/1024:$2}'; }
ra_temp_c()      { awk '{printf "%d", $1/1000}' /sys/class/thermal/thermal_zone0/temp 2>/dev/null; }
ra_disk()        { df -h / | awk 'NR==2{gsub(/%/,"",$5); print $5"|"$4}'; }
ra_uptime()      { uptime | sed 's/.*up \([^,]*\),.*/\1/'; }
ra_proxy_state() {
    local out code t
    out=$(curl -sS -m 5 --socks5 127.0.0.1:1070 -o /dev/null \
        -w '%{http_code}|%{time_total}' https://www.gstatic.com/generate_204 2>/dev/null)
    code=${out%%|*}; t=${out##*|}
    if [ "$code" = "204" ]; then echo "up|${t:-0}"; else echo "down|"; fi
}
ra_proxy_node() {
    local id name
    id=$(uci get passwall.@global[0].tcp_node 2>/dev/null)
    [ -z "$id" ] && { echo "unknown"; return; }
    name=$(echo "$RA_NODES" | awk -F'|' -v id="$id" '$2==id{print $1; exit}')
    [ -n "$name" ] && echo "$name" || {
        name=$(uci get "passwall.$id.remarks" 2>/dev/null)   # fall back to the node's own remark
        [ -n "$name" ] && echo "$name" || echo "$id"
    }
}
ra_usage_today() { "$RA_USAGE_SH" --today 2>/dev/null; }   # name|meta|bytes lines
ra_usage_month_rows() {  # [YYYY-MM] -> "key|bytes" summed per key (tolerant parse)
    local f
    f="$RA_USAGE_LOG_DIR/${1:-$(date +%Y-%m)}.log"
    awk -F'|' '{ b=$NF; k=$(NF-1); if (b ~ /^[0-9]+$/ && k ~ /./) { s[k]+=b } }
        END { for (k in s) print k "|" s[k] }' "$f" 2>/dev/null
}
ra_nlbw_macs() {
    /usr/sbin/nlbw -c json -g mac 2>/dev/null | jq -r '.data[] | [.[0], .[2], .[4]] | @tsv' 2>/dev/null | tr '\t' '|'
}
ra_wan_bytes() {
    awk '!/^lo:/ && /:/ { gsub(":","",$1); rx+=$2; tx+=$10 } END { print rx"|"tx }' /proc/net/dev 2>/dev/null
}
ra_balance_series() {  # date|gb lines, newest first (last 90)
    cat "$RA_BALANCE_LOG_DIR"/*.log 2>/dev/null |
        awk -F'|' '$1 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ && $2 ~ /[0-9]/ { print $1 "|" $2 }' |
        sort -r | head -90
}
ra_url_test() {  # <url> -> result string
    curl -sS -m 10 -o /dev/null -w 'HTTP %{http_code} in %{time_total}s (IP %{remote_ip})' "$1" 2>/dev/null
}
ra_node_id_by_remark() {  # <remark> -> first passwall node id with that remark
    uci show passwall 2>/dev/null |
        sed -n "s/^passwall\.\([^@.][^.]*\)\.remarks='\([^']*\)'/\2|\1/p" |
        awk -F'|' -v r="$1" '$1==r{print $2; exit}'
}
ra_node_id_by_protocol() {  # <protocol> -> first passwall node id with that protocol (e.g. hysteria2)
    uci show passwall 2>/dev/null |
        sed -n "s/^passwall\.\([^@.][^.]*\)\.protocol='\([^']*\)'/\2|\1/p" |
        awk -F'|' -v p="$1" '$1==p{print $2; exit}'
}
ra_resolve_node() {  # <name> -> node id: remark, else protocol (hysteria2), else RA_NODES alias
    local id
    id=$(ra_node_id_by_remark "$1")
    [ -z "$id" ] && id=$(ra_node_id_by_protocol "$1")
    [ -z "$id" ] && id=$(echo "$RA_NODES" | awk -F'|' -v n="$1" '$1==n{print $2; exit}')
    echo "$id"
}
ra_uci_switch() {  # <node name> — apply the documented passwall switch
    local id
    id=$(ra_resolve_node "$1")
    [ -z "$id" ] && return 1
    uci set passwall.@global[0].tcp_node="$id" 2>/dev/null
    uci commit passwall 2>/dev/null
    /etc/init.d/passwall restart 2>/dev/null
}
ra_do_reboot() {
    # Only a real OpenWrt has uci; anything else is a dev box and must not reboot.
    if command -v uci >/dev/null 2>&1; then reboot 2>/dev/null; else echo "skipped (not on router)" >&2; fi
}

# ---------- JSON builders ----------
ra_rows_to_json() {  # stdin: name|mac|bytes (sorted) -> rows JSON
    local out="" first=1 name mac bytes gb
    while IFS='|' read -r name mac bytes; do
        [ -z "$name" ] && continue
        gb=$(awk -v b="$bytes" 'BEGIN{printf "%.4f", b/1073741824}')
        if [ "$first" = 1 ]; then first=0; else out="$out,"; fi
        out="$out{\"name\":\"$(ra_esc "$name")\",\"mac\":\"$(ra_esc "$mac")\",\"gb\":$gb}"
    done
    echo "[$out]"
}

ra_json_status() {
    local load mem used total temp disk dpct dfree up ps pnode pstate plat
    load=$(ra_load)
    mem=$(ra_mem); used=${mem%% *}; total=${mem##* }
    temp=$(ra_temp_c)
    disk=$(ra_disk); dpct=${disk%%|*}; dfree=${disk##*|}
    up=$(ra_uptime)
    ps=$(ra_proxy_state); pstate=${ps%%|*}; plat=${ps##*|}
    pnode=$(ra_proxy_node)
    echo "{\"uptime\":\"$(ra_esc "$up")\",\"load\":\"$(ra_esc "$load")\",\"ram\":{\"used_mb\":${used:-0},\"total_mb\":${total:-0}},\"temp_c\":${temp:-null},\"disk\":{\"pct\":${dpct:-0},\"free\":\"$(ra_esc "$dfree")\"},\"proxy\":{\"state\":\"$pstate\",\"latency_s\":${plat:-0},\"node\":\"$(ra_esc "$pnode")\"}}"
}

ra_json_usage() {  # <today|month>
    local period="${1:-today}" out= first=1
    if [ "$period" = "month" ]; then
        local rows line key bytes name mac gb
        rows=$(ra_usage_month_rows | sort -t'|' -k2 -rn)
        while IFS='|' read -r key bytes; do
            [ -z "$key" ] && continue
            case "$key" in *:*) mac="$key";; *) mac="";; esac
            ra_is_excluded_mac "$mac" && continue
            name=$(ra_name_for_key "$key")
            if [ -z "$name" ]; then
                case "$key" in *:*) name="Unknown-$(echo "$key" | cut -c1-8)";; *) name="$key";; esac
            fi
            gb=$(awk -v b="$bytes" 'BEGIN{printf "%.4f", b/1073741824}')
            if [ "$first" = 1 ]; then first=0; else out="$out,"; fi
            out="$out{\"name\":\"$(ra_esc "$name")\",\"mac\":\"$(ra_esc "$mac")\",\"gb\":$gb}"
        done <<EOF
$rows
EOF
        echo "{\"period\":\"month\",\"rows\":[$out]}"
    else
        local rows name mac bytes
        rows=$(ra_usage_today | while IFS='|' read -r name meta bytes; do
            [ -z "$name" ] && continue
            case "$meta" in *:*) mac="$meta";; *) mac="";; esac
            ra_is_excluded_mac "$mac" && continue
            echo "$name|$mac|${bytes:-0}"
        done | sort -t'|' -k3 -rn)
        out=$(echo "$rows" | ra_rows_to_json)
        echo "{\"period\":\"today\",\"rows\":$out}"
    fi
}

ra_cost_table() {  # <rate> — stdin: name|mac|bytes -> {rows, total_gb, total_toman} (shared by cost & bill)
    local rate="$1" tmp total_gb total_toman name mac bytes toman gb share out="" first=1
    tmp=$(cat | while IFS='|' read -r name mac bytes; do
        [ -z "$name" ] && continue
        ra_is_excluded_mac "$mac" && continue
        t=$(awk -v r="$rate" -v b="${bytes:-0}" 'BEGIN{ c=r*b/1073741824; print int(c/1000+0.5)*1000 }')
        g=$(awk -v b="${bytes:-0}" 'BEGIN{printf "%.4f", b/1073741824}')
        echo "$name|$mac|${bytes:-0}|$t|$g"
    done | sort -t'|' -k3 -rn)
    total_gb=$(echo "$tmp" | awk -F'|' '{g+=$3} END{printf "%.4f", g/1073741824}')
    total_toman=$(echo "$tmp" | awk -F'|' '{t+=$4} END{print t+0}')
    while IFS='|' read -r name mac bytes toman gb; do
        [ -z "$name" ] && continue
        share=$(awk -v b="$bytes" -v t="$total_gb" 'BEGIN{ printf "%.1f", (t>0) ? (b/1073741824)/t*100 : 0 }')
        if [ "$first" = 1 ]; then first=0; else out="$out,"; fi
        out="$out{\"name\":\"$(ra_esc "$name")\",\"mac\":\"$(ra_esc "$mac")\",\"gb\":$gb,\"toman\":$toman,\"share\":$share}"
    done <<EOF
$tmp
EOF
    echo "{\"rows\":[$out],\"total_gb\":${total_gb:-0},\"total_toman\":${total_toman:-0}}"
}

ra_json_cost() {  # <yes|no>
    local friday="${1:-no}" rate_full rate_friday rate res
    rate_full=$(ra_conf_val "$RA_BILLING_CONF" RATE_FULL_TOMAN);   [ -z "$rate_full" ]  && rate_full=7700
    rate_friday=$(ra_conf_val "$RA_BILLING_CONF" RATE_FRIDAY_TOMAN); [ -z "$rate_friday" ] && rate_friday=4620
    if [ "$friday" = "yes" ]; then rate=$rate_friday; else rate=$rate_full; fi
    res=$(ra_usage_today | while IFS='|' read -r name meta bytes; do
        [ -z "$name" ] && continue
        case "$meta" in *:*) mac="$meta";; *) mac="";; esac
        echo "$name|$mac|${bytes:-0}"
    done | ra_cost_table "$rate")
    echo "{\"friday\":$([ "$friday" = "yes" ] && echo true || echo false),\"rate_full\":$rate_full,\"rate_friday\":$rate_friday,$(echo "$res" | sed 's/^{//')"
}

ra_json_bill() {  # <yes|no> [YYYY-MM]
    local friday="${1:-no}" month="${2:-$(date +%Y-%m)}" rate_full rate_friday rate res key mac name
    rate_full=$(ra_conf_val "$RA_BILLING_CONF" RATE_FULL_TOMAN);   [ -z "$rate_full" ]  && rate_full=7700
    rate_friday=$(ra_conf_val "$RA_BILLING_CONF" RATE_FRIDAY_TOMAN); [ -z "$rate_friday" ] && rate_friday=4620
    if [ "$friday" = "yes" ]; then rate=$rate_friday; else rate=$rate_full; fi
    res=$(ra_usage_month_rows "$month" | while IFS='|' read -r key bytes; do
        [ -z "$key" ] && continue
        case "$key" in *:*) mac="$key";; *) mac="";; esac
        name=$(ra_name_for_key "$key")
        if [ -z "$name" ]; then
            case "$key" in *:*) name="Unknown-$(echo "$key" | cut -c1-8)";; *) name="$key";; esac
        fi
        echo "$name|$mac|$bytes"
    done | ra_cost_table "$rate")
    echo "{\"period\":\"$month\",\"friday\":$([ "$friday" = "yes" ] && echo true || echo false),\"rate_full\":$rate_full,\"rate_friday\":$rate_friday,$(echo "$res" | sed 's/^{//')"
}

ra_json_balance() {
    local text ts total plans line2 mainq mainr pct expires days expired drain series out="" first=1
    if [ ! -f "$RA_BALANCE_REPORT" ]; then echo '{"cached":false,"as_of_unix":0}'; return; fi
    text=$(cat "$RA_BALANCE_REPORT" 2>/dev/null)
    ts=$(cat "$RA_BALANCE_REPORT_TS" 2>/dev/null || echo 0); [ -z "$ts" ] && ts=0
    total=$(echo "$text" | sed -n '1{s/.* \([0-9.]*\) GB left across \([0-9]*\) plan.*/\1/p}')
    plans=$(echo "$text" | sed -n '1{s/.* \([0-9.]*\) GB left across \([0-9]*\) plan.*/\2/p}')
    line2=$(echo "$text" | sed -n '2p')
    mainq=$(echo "$line2" | sed -n 's/Main: \([0-9]*\) GB.*/\1/p')
    mainr=$(echo "$line2" | sed -n 's/Main: [0-9]* GB · \([0-9.]*\) GB left.*/\1/p')
    pct=$(echo "$line2" | sed -n 's/.*(\([0-9]*\)%).*/\1/p')
    expires=$(echo "$line2" | sed -n 's/.*expires \([0-9-]*\) (.*/\1/p')
    days=$(echo "$line2" | sed -n 's/.*(\(~[0-9]*\)d).*/\1/p' | tr -dc '0-9')
    expired=$(echo "$text" | sed -n 's/^+\([0-9]*\) expired plan.*/\1/p')
    drain=$(echo "$text" | sed -n 's/^Drain[[:space:]]*//p' | head -1 | sed 's/ (est.*//')
    series=$(ra_balance_series)
    while IFS='|' read -r d v; do
        [ -z "$d" ] && continue
        if [ "$first" = 1 ]; then first=0; else out="$out,"; fi
        out="$out{\"date\":\"$d\",\"gb\":$v}"
    done <<EOF
$series
EOF
    echo "{\"cached\":true,\"as_of_unix\":$ts,\"total_gb\":${total:-null},\"plans\":${plans:-null},\"main\":{\"quota\":${mainq:-null},\"remain\":${mainr:-null},\"pct\":${pct:-null},\"expires\":\"$expires\",\"days\":${days:-null}},\"expired\":${expired:-0},\"drain\":\"$(ra_esc "$drain")\",\"series\":[$out]}"
}

ra_json_clients() {
    local out="" first=1 usage_map ts mac ip hostname client rest name bytes gb
    usage_map=$(ra_usage_today | awk -F'|' '{print $1"|"$3}')
    while read -r ts mac ip hostname client rest; do
        [ -z "$mac" ] && continue
        [ "$hostname" = "*" ] && hostname=""
        name=$(ra_name_for_key "$mac")
        if [ -z "$name" ]; then
            if [ -n "$hostname" ]; then name="$hostname"; else name="Unknown-$(echo "$mac" | cut -c1-8)"; fi
        fi
        bytes=$(echo "$usage_map" | awk -F'|' -v n="$name" '$1==n{print $2; exit}')
        [ -z "$bytes" ] && bytes=0
        gb=$(awk -v b="$bytes" 'BEGIN{printf "%.4f", b/1073741824}')
        if [ "$first" = 1 ]; then first=0; else out="$out,"; fi
        out="$out{\"mac\":\"$(ra_esc "$mac")\",\"ip\":\"$(ra_esc "$ip")\",\"name\":\"$(ra_esc "$name")\",\"hostname\":\"$(ra_esc "$hostname")\",\"today_gb\":$gb}"
    done < "$RA_DHCP_LEASES"
    echo "{\"clients\":[$out]}"
}

ra_json_live() {
    local out="" first=1 rx tx mac r t
    IFS='|' read -r rx tx <<EOF
$(ra_wan_bytes)
EOF
    while IFS='|' read -r mac r t; do
        [ -z "$mac" ] && continue
        ra_is_excluded_mac "$mac" && continue
        if [ "$first" = 1 ]; then first=0; else out="$out,"; fi
        out="$out{\"mac\":\"$(ra_esc "$mac")\",\"rx_bytes\":$r,\"tx_bytes\":$t}"
    done <<EOF
$(ra_nlbw_macs)
EOF
    echo "{\"ts\":$(ra_ts),\"wan\":{\"rx_bytes\":${rx:-0},\"tx_bytes\":${tx:-0}},\"devices\":[$out]}"
}

ra_json_history() {  # <balance|usage> [days]
    local kind="${1:-usage}" days="${2:-30}" n pts out="" first=1 d v
    [ "$days" -lt 1 ] 2>/dev/null && days=1
    if [ "$kind" = "balance" ]; then
        pts=$(ra_balance_series | sort | tail -n "$days")
        while IFS='|' read -r d v; do
            [ -z "$d" ] && continue
            if [ "$first" = 1 ]; then first=0; else out="$out,"; fi
            out="$out{\"ts\":\"$d\",\"value\":$v}"
        done <<EOF
$pts
EOF
        echo "{\"kind\":\"balance\",\"points\":[$out]}"
    else
        n=$(( days * 24 ))
        pts=$(cat "$RA_TELEMETRY_LOG" 2>/dev/null | tail -n "$n")
        while IFS='|' read -r d v rest; do
            [ -z "$d" ] && continue
            if [ "$first" = 1 ]; then first=0; else out="$out,"; fi
            out="$out{\"ts\":\"$(ra_esc "$d")\",\"value\":$v}"
        done <<EOF
$pts
EOF
        echo "{\"kind\":\"usage\",\"points\":[$out]}"
    fi
}

ra_json_devices() {
    local out="" first=1 mac name src watched bytes gb
    # custom-named devices
    while read -r mac name; do
        [ -z "$mac" ] && continue
        watched=false
        grep -qx "$mac" "$RA_WATCHLIST" 2>/dev/null && watched=true
        bytes=$(ra_usage_today | awk -F'|' -v n="$name" '$1==n{print $3; exit}')
        [ -z "$bytes" ] && bytes=0
        gb=$(awk -v b="$bytes" 'BEGIN{printf "%.4f", b/1073741824}')
        if [ "$first" = 1 ]; then first=0; else out="$out,"; fi
        out="$out{\"mac\":\"$(ra_esc "$mac")\",\"name\":\"$(ra_esc "$name")\",\"source\":\"user-names\",\"watched\":$watched,\"today_gb\":$gb}"
    done < "$RA_USER_NAMES"
    # watchlist macs not already named
    while read -r mac; do
        [ -z "$mac" ] && continue
        name=$(ra_name_for_key "$mac")
        [ -n "$name" ] && continue   # already emitted above
        hostname=$(awk -v m="$mac" '$2==m{print $4; exit}' "$RA_DHCP_LEASES" 2>/dev/null)
        if [ -n "$hostname" ] && [ "$hostname" != "*" ]; then name="$hostname"; src="lease"; else name="Unknown-$(echo "$mac" | cut -c1-8)"; src="default"; fi
        bytes=$(ra_usage_today | awk -F'|' -v n="$name" '$1==n{print $3; exit}')
        [ -z "$bytes" ] && bytes=0
        gb=$(awk -v b="$bytes" 'BEGIN{printf "%.4f", b/1073741824}')
        if [ "$first" = 1 ]; then first=0; else out="$out,"; fi
        out="$out{\"mac\":\"$(ra_esc "$mac")\",\"name\":\"$(ra_esc "$name")\",\"source\":\"$src\",\"watched\":true,\"today_gb\":$gb}"
    done < "$RA_WATCHLIST"
    echo "{\"devices\":[$out]}"
}

# ---------- write actions ----------
ra_rename_device() {
    local mac name bad
    mac=$(echo "$RA_BODY" | jq -r '.mac // ""' 2>/dev/null)
    name=$(echo "$RA_BODY" | jq -r '.name // ""' 2>/dev/null)
    [ -z "$mac" ] && { RA_STATUS=400; echo '{"error":"mac required"}'; return; }
    bad=$(printf '%s' "$name" | tr -d 'A-Za-z0-9 _.-')
    [ -n "$bad" ] && { RA_STATUS=400; echo '{"error":"invalid name"}'; return; }
    name=$(echo "$name" | cut -c1-24)
    [ -z "$name" ] && { RA_STATUS=400; echo '{"error":"invalid name"}'; return; }
    grep -v "^$mac " "$RA_USER_NAMES" > "$RA_USER_NAMES.tmp" 2>/dev/null || true
    mv "$RA_USER_NAMES.tmp" "$RA_USER_NAMES" 2>/dev/null
    echo "$mac $name" >> "$RA_USER_NAMES"
    echo "{\"ok\":true,\"mac\":\"$(ra_esc "$mac")\",\"name\":\"$(ra_esc "$name")\"}"
}

ra_watch_device() {
    local mac on
    mac=$(echo "$RA_BODY" | jq -r '.mac // ""' 2>/dev/null)
    on=$(echo "$RA_BODY" | jq -r '.on // false' 2>/dev/null)
    [ -z "$mac" ] && { RA_STATUS=400; echo '{"error":"mac required"}'; return; }
    if [ "$on" = "true" ]; then
        grep -qx "$mac" "$RA_WATCHLIST" 2>/dev/null || echo "$mac" >> "$RA_WATCHLIST"
    else
        grep -vx "$mac" "$RA_WATCHLIST" > "$RA_WATCHLIST.tmp" 2>/dev/null || true
        mv "$RA_WATCHLIST.tmp" "$RA_WATCHLIST" 2>/dev/null
    fi
    echo "{\"ok\":true,\"watched\":$on}"
}

ra_set_friday() {
    local f val
    f=$(echo "$RA_BODY" | jq -r '.friday // false' 2>/dev/null)
    [ "$f" = "true" ] && val=yes || val=no
    if grep -q '^LAST_FRIDAY=' "$RA_BILLING_CONF" 2>/dev/null; then
        sed -i "s/^LAST_FRIDAY=.*/LAST_FRIDAY=$val/" "$RA_BILLING_CONF" 2>/dev/null
    else
        echo "LAST_FRIDAY=$val" >> "$RA_BILLING_CONF"
    fi
    echo "{\"ok\":true,\"friday\":$f}"
}

ra_test_url() {
    local url result
    url=$(echo "$RA_BODY" | jq -r '.url // ""' 2>/dev/null)
    [ -z "$url" ] && { RA_STATUS=400; echo '{"error":"url required"}'; return; }
    case "$url" in http://*|https://*) : ;; *) url="https://$url" ;; esac
    result=$(ra_url_test "$url")
    [ -z "$result" ] && result="unreachable"
    echo "{\"ok\":true,\"url\":\"$(ra_esc "$url")\",\"result\":\"$(ra_esc "$result")\"}"
}

ra_switch_proxy() {
    local node
    node=$(echo "$RA_BODY" | jq -r '.node // ""' 2>/dev/null)
    [ -z "$node" ] && { RA_STATUS=400; echo '{"error":"node required"}'; return; }
    if [ -z "$(ra_resolve_node "$node")" ]; then
        RA_STATUS=400; echo '{"error":"unknown node"}'; return
    fi
    ra_uci_switch "$node"
    echo "{\"ok\":true,\"node\":\"$(ra_esc "$node")\"}"
}

ra_reboot() {
    ra_do_reboot
    echo '{"ok":true}'
}

# ---------- routing ----------
ra_qp() {  # ra_qp <name> — from QUERY_STRING
    echo "$QUERY_STRING" | tr '&' '\n' | sed -n "s/^$1=//p" | head -1
}

ra_route() {
    RA_STATUS=200
    if [ "$REQUEST_METHOD" = "POST" ]; then
        RA_BODY=$(cat)
    else
        RA_BODY=""
    fi
    if ! ra_authed; then
        RA_STATUS=401
        echo '{"error":"unauthorized"}'
    else
        case "$PATH_INFO" in
            /status)        ra_json_status ;;
            /usage)         ra_json_usage "$(ra_qp period)" ;;
            /cost)          ra_json_cost "$(ra_qp friday)" ;;
            /bill)          ra_json_bill "$(ra_qp friday)" "$(ra_qp month)" ;;
            /balance)       ra_json_balance ;;
            /clients)       ra_json_clients ;;
            /live)          ra_json_live ;;
            /history)       ra_json_history "$(ra_qp kind)" "$(ra_qp days)" ;;
            /devices)       ra_json_devices ;;
            /device/rename) ra_rename_device ;;
            /device/watch)  ra_watch_device ;;
            /friday)        ra_set_friday ;;
            /test)          ra_test_url ;;
            /proxy/switch)  ra_switch_proxy ;;
            /reboot)        ra_reboot ;;
            *)              RA_STATUS=404; echo '{"error":"unknown endpoint"}' ;;
        esac
    fi
    # Status marker for the dispatcher: it runs us in a subshell so it cannot
    # read RA_STATUS; it strips this trailing line before emitting the JSON.
    echo "@@STATUS:$RA_STATUS"
}
