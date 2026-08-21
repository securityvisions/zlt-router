#!/bin/sh
# usage-collect.sh — per-device traffic accounting daemon (no nlbwmon needed).
#
# Method: poll /proc/net/nf_conntrack every 5s, sum per-LAN-IP byte counters
# (orig bytes = upload, reply bytes = download), accumulate positive deltas
# into today's per-device file. Redirected (proxied) flows are never
# hw_nat-offloaded, so international traffic counts fully; short-lived
# entries are the only leak — the usage card calibrates the attributed
# total against the modem's exact WAN counters (vendor cmd 18).
#
# Modes:
#   usage-collect.sh loop   — daemon body (procd service x28-usage)
#   usage-collect.sh snap   — one collection cycle (debug/testing)
#   usage-collect.sh roll   — day rollover + weekly bill (called by loop)
#
# State (all under /data/proxy/usage/):
#   snap              last per-IP conntrack sums + boot uptime (boot-aware)
#   day/YYYY-MM-DD    mac|ip|name|up_bytes|down_bytes (today)
#   month/YYYY-MM.log day summaries (monthly billing source)
#   week-marker       last ISO week the Friday bill card was sent
#
# Canonical copy: router/x28/usage-collect.sh — deploys to /data/proxy/usage/.

DIR=/data/proxy/usage

mkdir -p "$DIR/day" "$DIR/month"

now_day()  { date +%F; }
now_week() { date +%G-W%V; }

# modem WAN totals since boot (exact — used for calibration display)
wan_totals() {
    . /data/proxy/x28lib.sh
    x28_session >/dev/null 2>&1 || { echo "0 0"; return; }
    curl -s -m 6 -H "Content-Type: application/json" \
        -d "{\"cmd\":18,\"method\":\"GET\",\"sessionId\":\"$X28_SID\",\"language\":\"en\"}" \
        "$X28_BASE" 2>/dev/null | \
        sed -n 's/.*"rxBytes":"\([0-9]*\)".*"txBytes":"\([0-9]*\)".*/\1 \2/p' | head -1
}

# one cycle: conntrack sums → delta vs snap → merge into today file.
cycle() {
    day=$(now_day)
    dayf="$DIR/day/$day"

    # boot-aware baseline: uptime went backwards → reboot → drop snapshot
    upnow=$(cut -d. -f1 /proc/uptime)
    upthen=$(sed -n 's/^#uptime //p' "$DIR/snap" 2>/dev/null)
    [ -n "$upthen" ] && [ "$upnow" -lt "$upthen" ] && rm -f "$DIR/snap"

    {
        echo "#SNAP"
        cat "$DIR/snap" 2>/dev/null
        echo "#DAY"
        cat "$dayf" 2>/dev/null
        echo "#CT"
        awk -v net="192.168.70." -v me="192.168.70.1" '{
            nsrc = 0; ip = ""; up = 0; down = 0
            for (i = 1; i <= NF; i++) {
                if (index($i, "src=") == 1) {
                    nsrc++
                    if (nsrc == 1) { v = substr($i, 5); if (index(v, net) == 1 && v != me) ip = v }
                } else if (index($i, "bytes=") == 1) {
                    v = substr($i, 7) + 0
                    if (nsrc >= 2) down += v; else up += v
                }
            }
            if (ip != "") { u[ip] += up; d[ip] += down }
        } END { for (ip in u) printf "%s %d %d\n", ip, u[ip], d[ip] }' /proc/net/nf_conntrack
        echo "#LEASES"
        cat /tmp/dnsmasq.leases 2>/dev/null | awk '{print $3, $2, ($4=="*"?"unknown":$4)}'
    } | awk -F"[ |]" -v OFS="|" '
        /^#SNAP/   { sec = "snap"; next }
        /^#DAY/    { sec = "day"; next }
        /^#CT/     { sec = "ct"; next }
        /^#LEASES/ { sec = "le"; next }
        /^#/       { next }
        !NF        { next }
        sec == "snap" { lastu[$1] = $2; lastd[$1] = $3; next }
        sec == "day"  { mac[$2] = $1; name[$2] = $3; up[$2] = $4; dn[$2] = $5;
                        seen[$2] = 1; order[++n] = $2; next }
        sec == "ct"   { ip = $1
                        du = $2 - lastu[ip];  if (du  < 0) du  = 0
                        dd = $3 - lastd[ip];  if (dd < 0) dd = 0
                        up[ip] += du; dn[ip] += dd
                        if (!seen[ip]) { seen[ip] = 1; order[++n] = ip }
                        ctnow[ip] = 1
                        ctu[ip] = $2; ctd[ip] = $3
                        next }
        sec == "le"   { lmac[$1] = $2; lname[$1] = $3; next }
        END {
            for (i = 1; i <= n; i++) {
                ip = order[i]
                if (up[ip] + dn[ip] <= 0 && !seen[ip]) continue
                m = (mac[ip] != "" && mac[ip] != "unknown") ? mac[ip] : (lmac[ip] != "" ? lmac[ip] : "unknown")
                s = (name[ip] != "" && name[ip] != "unknown" && name[ip] != ip) ? name[ip] : (lname[ip] != "" ? lname[ip] : ip)
                print m, ip, s, up[ip] + 0, dn[ip] + 0
            }
            print "#uptime " upnow > "/dev/stderr"
        }
    ' upnow="$upnow" > "$dayf.new" 2> "$DIR/.upnow"
    rc=$?
    if [ "$rc" = "0" ] && [ -s "$dayf.new" ]; then
        mv "$dayf.new" "$dayf"
        { echo "#uptime $(cat "$DIR/.upnow" 2>/dev/null | sed 's/#uptime //')"
          awk -F"|" '!/^#/ {print $2, $4, $5}' "$dayf"; } > "$DIR/snap"
    else
        rm -f "$dayf.new"
    fi
    rm -f "$DIR/.upnow"
    return 0
}

# roll — day summary into monthly log + Friday weekly bill card.
roll() {
    day=$(now_day)
    dayf="$DIR/day/$day"
    if [ -f "$dayf" ] && [ ! -f "$DIR/month/.rolled-$day" ]; then
        tot_up=$(awk -F"|" '!/^#/ {s+=$4} END{print s+0}' "$dayf")
        tot_down=$(awk -F"|" '!/^#/ {s+=$5} END{print s+0}' "$dayf")
        echo "$day total_up=$tot_up total_down=$tot_down" >> "$DIR/month/$(date +%Y-%m).log"
        touch "$DIR/month/.rolled-$day"
        find "$DIR/day" -type f -mtime +35 -name "20*" -delete 2>/dev/null
    fi
    if [ "$(date +%u)" = "5" ] && [ "$(date +%H)" -ge 20 ]; then
        wk=$(now_week)
        if [ "$(cat "$DIR/week-marker" 2>/dev/null)" != "$wk" ]; then
            echo "$wk" > "$DIR/week-marker"
            card=$(sh "${0%/*}/x28-usage.sh" week 2>/dev/null)
            [ -n "$card" ] && sh /data/proxy/tg-notify.sh "Weekly bill" "$card"
        fi
    fi
}

case "${1:-loop}" in
    snap)  cycle ;;
    roll)  roll ;;
    loop)
        lastday=$(now_day)
        while :; do
            cycle
            [ "$(now_day)" != "$lastday" ] && { roll; lastday=$(now_day); }
            sleep 5
        done ;;
esac
