#!/bin/sh
# Alert on new devices appearing in DHCP leases + watched MACs becoming active
. /etc/tg.conf 2>/dev/null || exit 1
HN_LIB="${HN_LIB:-/root/hnlib.sh}"; [ -f "$HN_LIB" ] && . "$HN_LIB"
STATE=/tmp/devices_known
WATCHLIST=/etc/usage-log/watchlist
WSTATE=/tmp/watch_state
WATCH_QUIET=1800   # seconds between repeat alerts for a watched mac

if [ ! -f "$STATE" ]; then
    awk '{print $2}' /tmp/dhcp.leases | sort > "$STATE"
fi

TMP=$(mktemp)
awk '{print $2}' /tmp/dhcp.leases | sort > "$TMP"

while read -r mac; do
    [ -z "$mac" ] && continue
    if ! grep -qx "$mac" "$STATE"; then
        line=$(awk -v m="$mac" '$2==m{print; exit}' /tmp/dhcp.leases)
        ip=$(echo "$line" | awk '{print $3}')
        name=$(/root/usage.sh --name "$mac")
        [ -z "$name" ] && name="unknown"
        /root/tg.sh --card "📱 New device" "${name} (${ip})"
        hn_event_record device_joined "${name} (${ip})" "$mac" >/dev/null 2>&1 || true
    fi
done < "$TMP"

mv "$TMP" "$STATE"

# --- watched MACs (static-IP devices nlbwmon sees but DHCP never leases) ---
watch_bytes() {  # mac -> current total bytes (0 if absent)
    /usr/sbin/nlbw -c json -g mac 2>/dev/null | jq -r --arg m "$1" '.data[] | select(.[0]==$m) | (.[2]+.[4])' 2>/dev/null | head -1
}

watch_check() {
    [ -f "$WATCHLIST" ] || return 0
    local now mac cur line last lastalert name gb
    now=$(date +%s)
    while read -r mac; do
        [ -z "$mac" ] && continue
        cur=$(watch_bytes "$mac")
        [ -z "$cur" ] && cur=0
        line=$(grep "^$mac|" "$WSTATE" 2>/dev/null | head -1)
        if [ -z "$line" ]; then
            echo "$mac|$cur|$now" >> "$WSTATE"   # seed, no immediate alert
            continue
        fi
        IFS='|' read -r m last lastalert <<EOF
$line
EOF
        if [ "$cur" -gt "$last" ] && [ $(( now - lastalert )) -ge "$WATCH_QUIET" ]; then
            name=$(/root/usage.sh --name "$mac")
            [ -z "$name" ] && name="$mac"
            gb=$(awk -v b="$cur" 'BEGIN{printf "%.2f", b/1073741824}')
            /root/tg.sh --card "📶 Device active again" "${name} — ${gb} GB total (${mac})"
            grep -v "^$mac|" "$WSTATE" > "$WSTATE.tmp" 2>/dev/null || true
            mv "$WSTATE.tmp" "$WSTATE" 2>/dev/null
            echo "$mac|$cur|$now" >> "$WSTATE"
        else
            grep -v "^$mac|" "$WSTATE" > "$WSTATE.tmp" 2>/dev/null || true
            mv "$WSTATE.tmp" "$WSTATE" 2>/dev/null
            echo "$mac|$cur|$lastalert" >> "$WSTATE"
        fi
    done < "$WATCHLIST"
}

watch_check
