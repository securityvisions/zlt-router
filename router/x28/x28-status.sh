#!/bin/sh
# x28-status.sh — the X28 status card: live link + system + service state.
# One line per metric, ready for Telegram/plain-text display. Read-only.
#
# Canonical copy: router/x28/x28-status.sh — deploys to /data/proxy/x28-status.sh.

l=$(timeout 20 sh /data/proxy/linkstate.sh 2>/dev/null)
gv() { printf '%s' "$l" | sed -n "s/^$1=//p" | head -1; }

op=$(gv operator); tech=$(gv tech); plmn=$(gv plmn)
rsrp=$(gv rsrp); rsrp5=$(gv rsrp_5g)

# data probe (same as the watchdog: HTTPS by IP, no DNS)
data=DOWN
code=$(curl -k -s -m 8 -o /dev/null -w '%{http_code}' https://1.1.1.1 2>/dev/null)
case "$code" in 200|204|301|302) data=OK ;; esac

# proxy probe (crypto engine -> VPS egress)
proxy=DOWN
code=$(curl -s -m 10 -x socks5h://192.168.70.1:1080 -o /dev/null -w '%{http_code}' https://www.instagram.com/ 2>/dev/null)
[ "$code" = "200" ] && proxy=OK

# devices online (arp entries on br0)
dev=$(awk '$1 ~ /^192\.168\.70\./ && $3=="0x2"{n++} END{print n+0}' /proc/net/arp 2>/dev/null)

up=$(cut -d. -f1 /proc/uptime 2>/dev/null || echo 0)
up_h=$((up/3600)); up_m=$(((up%3600)/60))
load=$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null)

ram_free=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo 2>/dev/null)
disk_free=$(df -k /data 2>/dev/null | awk 'NR==2{print int($4/1024)}')

tz=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1)
temp=""; [ -n "$tz" ] && temp="$((tz/1000))C"

svc=""
pgrep -f 'xray run'          >/dev/null 2>&1 && svc="xray"     || svc="XRAY-DOWN"
pgrep -f 'operator-watchdog' >/dev/null 2>&1 && svc="$svc watchdog" || svc="$svc WATCHDOG-DOWN"
pidof dnsmasq >/dev/null 2>&1 && svc="$svc dns" || svc="$svc DNS-DOWN"

echo "Operator  ${op:-?} (${plmn:-?}) - ${tech:-?}"
echo "Signal    RSRP ${rsrp:-?} dBm${rsrp5:+ - NR ${rsrp5} dBm}"
echo "Data      $data (direct probe)"
echo "Proxy     $proxy (VPS egress)"
echo "Devices   ${dev:-0} online"
echo "Uptime    ${up_h}h ${up_m}m - load ${load:-?}"
echo "RAM       ${ram_free:-?} MB free - /data ${disk_free:-?} MB free"
[ -n "$temp" ] && echo "Temp      $temp"
echo "Services  $svc"
