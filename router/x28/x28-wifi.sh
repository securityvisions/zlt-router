#!/bin/sh
# x28-wifi.sh — WiFi share QR helper.
# Reads /data/proxy/wifi.conf (ssid, psk) and generates WIFI URI and QR image.
# Usage: x28-wifi.sh uri | qr | card
# Env: WIFI_CONF, TMP_QR
set -eu

WIFI_CONF="${WIFI_CONF:-/data/proxy/wifi.conf}"
TMP_QR="${TMP_QR:-/tmp/wifi-qr.png}"

# wifi_escape <string> — escape \ ; , : " per WIFI URI spec
wifi_escape() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/;/\\;/g' -e 's/,/\\,/g' -e 's/:/\\:/g' -e 's/"/\\"/g'
}

wifi_uri() {
    local ssid="" psk="" line key val
    if [ ! -f "$WIFI_CONF" ]; then
        echo ""; return 1
    fi
    while IFS='=' read -r key val; do
        case "$key" in
            ssid) ssid="$val" ;;
            psk|password|pass) psk="$val" ;;
        esac
    done < "$WIFI_CONF" 2>/dev/null
    # trim
    ssid=$(printf '%s' "$ssid" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    psk=$(printf '%s' "$psk" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -n "$ssid" ] || { echo ""; return 1; }
    esc_ssid=$(wifi_escape "$ssid")
    esc_psk=$(wifi_escape "$psk")
    if [ -n "$psk" ]; then
        printf 'WIFI:S:%s;T:WPA;P:%s;;' "$esc_ssid" "$esc_psk"
    else
        printf 'WIFI:S:%s;T:nopass;;' "$esc_ssid"
    fi
}

wifi_qr() {
    uri=$(wifi_uri) || { echo "WiFi credentials not provisioned — create $WIFI_CONF with ssid= and psk=" >&2; return 1; }
    # try qrencode
    if command -v qrencode >/dev/null 2>&1; then
        qrencode -o "$TMP_QR" -s 6 -m 2 "$uri" 2>/dev/null && printf '%s' "$TMP_QR" && return 0
    fi
    # try opkg qrencode path
    if [ -x /usr/bin/qrencode ]; then
        /usr/bin/qrencode -o "$TMP_QR" -s 6 -m 2 "$uri" 2>/dev/null && printf '%s' "$TMP_QR" && return 0
    fi
    # fallback: try static binary at /data/proxy/qrencode
    if [ -x /data/proxy/qrencode ]; then
        /data/proxy/qrencode -o "$TMP_QR" -s 6 -m 2 "$uri" 2>/dev/null && printf '%s' "$TMP_QR" && return 0
    fi
    echo "qrencode not available — install via opkg install qrencode or provide /data/proxy/qrencode" >&2
    return 1
}

case "${1:-uri}" in
    uri) wifi_uri ;;
    qr) wifi_qr ;;
    card)
        if uri=$(wifi_uri 2>/dev/null); then
            echo "📶 WiFi Share"
            echo "──────────────"
            # try to get ssid for display
            ssid=$(sed -n 's/^ssid=//p' "$WIFI_CONF" 2>/dev/null | head -1)
            echo "SSID: $ssid"
            echo "URI: $uri"
            echo "Scan the QR photo to join"
        else
            echo "📶 WiFi Share"
            echo "──────────────"
            echo "WiFi credentials not provisioned"
            echo "Create $WIFI_CONF with:"
            echo "ssid=YourSSID"
            echo "psk=YourPassword"
        fi
        ;;
    *) wifi_uri ;;
esac
