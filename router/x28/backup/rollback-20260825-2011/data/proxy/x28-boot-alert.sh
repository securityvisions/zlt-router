#!/bin/sh
# x28-boot-alert.sh — "X28 back online" Telegram card after a reboot.
# Backgrounded from rc.local: waits for the proxy path to be usable, then
# sends the status card. Best-effort; exits silently on any failure.
#
# Canonical copy: router/x28/x28-boot-alert.sh — deploys to /data/proxy/x28-boot-alert.sh.

# wait up to ~3 min for the crypto engine path (xray up + egress reachable)
i=0
while [ $i -lt 18 ]; do
    code=$(curl -s -m 8 -x socks5h://192.168.70.1:1080 -o /dev/null \
        -w '%{http_code}' https://www.instagram.com/ 2>/dev/null)
    [ "$code" = "200" ] && break
    sleep 10; i=$((i+1))
done

up=$(cut -d. -f1 /proc/uptime 2>/dev/null || echo 0)
body=$(sh /data/proxy/x28-status.sh 2>/dev/null)
sh /data/proxy/tg-notify.sh "X28 back online (up ${up}s)" "$body" 2>/dev/null || true
exit 0
