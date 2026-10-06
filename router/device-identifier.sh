#!/bin/sh
# device-identifier.sh — Deep Device & OS Fingerprinter for OpenWrt.
#
# Identifies device type, OS, and hardware vendor even with Randomized MACs
# (Private Wi-Fi Addresses) using 4-layer fusion:
#   1. User explicit overrides (/etc/usage-log/user-names)
#   2. Hardware IEEE OUI lookup (for non-randomized MACs)
#   3. DHCP Option 55 (PRL) & Option 60 (VCI) protocol signatures
#   4. DHCP hostname and mDNS/SSDP hints

set -u

NAMES_CACHE="${NAMES_CACHE:-/etc/usage-log/names}"
USER_NAMES="${USER_NAMES:-/etc/usage-log/user-names}"
INVENTORY_TSV="${INVENTORY_TSV:-/etc/usage-log/device-inventory.tsv}"
DHCP_LEASES="${DHCP_LEASES:-/tmp/dhcp.leases}"

mkdir -p "$(dirname "$NAMES_CACHE")" 2>/dev/null || true

# Test if MAC address is randomized (locally administered bit 0x02 set in 1st octet)
dev_is_random_mac() {
    local mac="$1"
    local oct1="${mac%%:*}"
    [ -z "$oct1" ] && return 1
    # Convert hex to decimal
    local dec
    dec=$(printf "%d" "0x$oct1" 2>/dev/null || echo 0)
    # Bit 1 (value 2) set = locally administered / randomized
    if [ $(( (dec & 2) != 0 )) -eq 1 ]; then
        return 0
    else
        return 1
    fi
}

# Fast lookup for top consumer device manufacturers by OUI prefix
dev_oui_vendor() {
    local mac
    mac=$(printf '%s' "$1" | tr 'A-F' 'a-f')
    local pfx
    pfx=$(printf '%s' "$mac" | cut -d: -f1-3)

    case "$pfx" in
        # Apple
        f4:28:9d|3a:7e:c0|36:44:25|f6:a0:83|00:17:f2|00:1c:b3|00:25:00|00:26:08|04:54:53|04:db:56|08:66:98|0c:51:01|14:7d:da|18:af:61|20:ee:28|28:cf:e9|34:36:3b|3c:07:54|40:6c:8f|48:d7:05|50:bc:96|54:26:96|58:55:ca|60:03:08|64:76:ba|68:fe:f7|70:11:24|74:81:14|7c:d1:c3|80:49:71|88:66:5a|90:72:40|98:01:a7|a4:83:e7|ac:bc:32|b8:e8:56|c0:9f:42|c8:69:cd|d0:03:4b|d8:bb:2c|e0:b9:e5|e8:04:0b|f0:98:9d|f8:ff:c2)
            echo "Apple" ;;
        # Samsung
        c8:12:0b|00:07:ab|00:12:47|00:15:99|00:1a:8a|00:21:19|00:24:54|08:37:3d|0c:14:20|14:49:e0|1c:5a:3e|24:4b:03|2c:44:01|34:14:5f|38:0a:94|40:16:3b|48:44:f7|50:56:bf|58:c3:8b|60:6b:bd|68:eb:ae|70:f9:27|78:47:1d|84:25:19|8c:77:12|94:35:0a|9c:02:98|a0:0b:ba|a8:7c:01|b0:c5:54|b8:57:d8|c4:73:1e|cc:07:ab|d4:e6:b7|dc:71:44|e4:b0:21|ec:1f:72|f4:7b:5e|fc:a1:3e)
            echo "Samsung" ;;
        # Xiaomi / POCO / Redmi
        16:f7:3c|00:9e:c8|04:cf:8c|0c:98:38|14:f6:5a|18:59:36|20:34:fb|28:6c:07|34:80:0d|3c:cd:5d|44:23:7c|4c:49:e3|50:64:2b|58:44:98|64:cc:2e|74:51:ba|78:11:dc|88:c9:b3|9c:99:a0|a4:45:19|ac:c1:ee|b0:e5:ed|b8:86:87|c4:6b:b4|d4:97:0b|e0:cc:7a|ec:d0:9f|f4:8e:38|fc:a8:9a)
            echo "Xiaomi" ;;
        # Lenovo / LCFC (ThinkPad / Legion)
        a8:2b:dd|00:1a:6b|00:21:86|00:59:07|08:3e:8e|1c:39:47|28:d2:44|34:13:e8|40:8d:5c|50:76:af|54:ee:75|6c:4b:90|70:5a:0f|7c:b0:c2|88:70:8c|98:fa:9b|a4:b1:c1|b0:35:9f|c8:5b:76|d4:3b:04|e0:d5:5e|ec:79:49|f4:2e:7f)
            echo "Lenovo" ;;
        # Nothing Phone
        22:7d:f2|00:1e:b4)
            echo "Nothing" ;;
        # TP-Link
        5c:a6:e6|00:0a:eb|00:14:78|00:19:e0|00:21:27|00:23:cd|00:25:86|0c:80:63|14:cf:92|1c:60:de|20:dc:e6|30:b5:c2|34:e8:94|40:31:3c|48:22:54|50:3e:aa|54:e6:fc|60:32:b1|64:66:b3|6c:5a:b0|70:4f:57|78:44:76|84:16:f9|8c:21:0a|90:f6:52|98:48:27|a0:f3:c1|a8:40:41|b0:95:75|b4:b0:24|bc:46:99|c0:25:e9|c4:70:0b|cc:32:e5|d8:0d:17|d8:47:32|dc:fe:18|e4:c3:2a|ec:17:2f|f4:ec:38)
            echo "TP-Link" ;;
        # Intel Wi-Fi / NIC
        10:02:b5|00:02:b3|00:03:47|00:04:23|00:0e:0c|00:13:02|00:15:00|00:1b:21|00:1e:67|00:21:6a|00:23:14|00:24:d7|00:26:c7|08:11:96|0c:8b:7d|24:77:03|34:13:e8|3c:fd:fe|48:51:b7|4c:79:6e|58:94:6b|68:05:ca|70:1c:e8|7c:57:58|84:fd:d1|8c:8d:28|94:e6:f7|9c:b6:d0|a4:4e:31|ac:72:89|b4:96:91|c8:96:65|d4:81:d7|dc:53:60|e4:a7:a0|f4:8c:50|f8:63:3f)
            echo "Intel" ;;
        # Foxconn / Hon Hai (Sony / Apple / Console cards)
        c4:46:19|00:01:6c|00:04:e2|00:0e:2e|00:15:58|00:19:7e|00:21:85|14:b3:1f|24:fd:52|30:52:cb|38:59:f9|40:61:86|48:5d:60|54:04:a6|60:67:20|6c:71:d9|74:27:ea|7c:70:db|84:a6:c8|90:00:4e|98:01:a7|a4:db:30|b0:25:aa|bc:77:37|c8:f7:50|d0:27:88|dc:85:de|e0:69:95|ec:55:f9|f4:6d:04)
            echo "Foxconn" ;;
        *)
            echo "" ;;
    esac
}

# Infer platform / OS from DHCP Option 55 (PRL), Option 60 (VCI), and Hostname
dev_infer_os() {
    local prl="${1:-}"
    local vci="${2:-}"
    local host="${3:-}"

    # Priority A: Check explicit Vendor Class Identifier (Option 60)
    case "$vci" in
        *MSFT*|*Microsoft*) echo "Windows"; return ;;
        *Tizen*|*Samsung*|*DTV*) echo "Samsung-TV"; return ;;
        *LG*|*webOS*) echo "LG-TV"; return ;;
        *android*) echo "Android"; return ;;
        *Macintosh*|*Darwin*) echo "macOS"; return ;;
    esac

    # Priority B: Check explicit hostname clues
    case "$host" in
        *WIN*|*DESKTOP-*|*LAPTOP-*) echo "Windows"; return ;;
        *iPhone*|*iPad*|*Apple*) echo "iOS"; return ;;
        *Galaxy*|*SM-*) echo "Android-Galaxy"; return ;;
        *Redmi*|*Xiaomi*|*POCO*|*Mi-*) echo "Android-Xiaomi"; return ;;
        *Nothing*) echo "Android-Nothing"; return ;;
        *[TV]*|*SmartTV*|*QLED*|*webos*) echo "Smart-TV"; return ;;
    esac

    # Priority C: Check Option 55 Parameter Request List (PRL)
    case "$prl" in
        # Windows: NetBIOS 44,46,47 or static route 249
        *249*|*44,46,47*)
            echo "Windows"; return ;;
        # Apple (iOS / macOS): Domain search 119 + WPAD 252 (Never requests MTU 26 or Broadcast 28)
        *119,252*|*252,119*|*1,121,3,6,15,119,252*)
            case "$prl" in
                *26*|*28*) ;; # Fall-through if has MTU/Broadcast
                *) echo "iOS"; return ;;
            esac
            ;;
        # Smart TV signatures: Broadcast 28 + static route 33 or vendor 43
        *28,33,43*|*28,43*)
            echo "Smart-TV"; return ;;
        # Android (Stock / HyperOS / OneUI): Always requests MTU 26 & Broadcast 28
        *26,28*|*28,51,58,59*)
            echo "Android"; return ;;
    esac

    echo "Unknown"
}

# Resolve final human-friendly label for device
dev_label_for_mac() {
    local mac
    mac=$(printf '%s' "$1" | tr 'A-F' 'a-f')
    local host="${2:-}"
    local prl="${3:-}"
    local vci="${4:-}"

    # 1. User manual override wins
    if [ -f "$USER_NAMES" ]; then
        local un
        un=$(awk -v m="$mac" 'tolower($1)==tolower(m) {print $2; exit}' "$USER_NAMES" 2>/dev/null)
        if [ -n "$un" ]; then
            echo "$un"
            return
        fi
    fi

    # 2. If known hostname provided, check if informative
    case "$host" in
        WIN10-PC|Nothing-Phone-2|Redmi-Note-9S|Samsung|parsavisions-wifi)
            echo "$host"; return ;;
        *iPhone*|*iPad*|*MacBook*)
            echo "$host"; return ;;
    esac

    # 3. Check OUI if hardware MAC
    local oui=""
    if ! dev_is_random_mac "$mac"; then
        oui=$(dev_oui_vendor "$mac")
    fi

    # 4. Infer OS
    local os
    os=$(dev_infer_os "$prl" "$vci" "$host")

    # Combine into readable label
    if [ -n "$oui" ]; then
        if [ -n "$host" ] && [ "$host" != "*" ]; then
            echo "[$oui] $host"
        elif [ "$os" != "Unknown" ]; then
            echo "[$oui] $os"
        else
            echo "[$oui] Device"
        fi
    else
        # Randomized MAC or unmapped hardware MAC
        if [ "$os" != "Unknown" ]; then
            if [ -n "$host" ] && [ "$host" != "*" ]; then
                echo "[$os] $host"
            else
                local short_mac
                short_mac=$(printf '%s' "$mac" | cut -c1-8)
                echo "[$os] Device-$short_mac"
            fi
        else
            if [ -n "$host" ] && [ "$host" != "*" ]; then
                echo "$host"
            else
                echo "Unknown-$(printf '%s' "$mac" | cut -c1-8)"
            fi
        fi
    fi
}

# Scan current DHCP leases and auto-label everything into NAMES_CACHE
dev_scan_leases() {
    [ -f "$DHCP_LEASES" ] || return 0
    while read -r _ts mac ip host _clid; do
        [ -z "$mac" ] && continue
        local cur_label
        cur_label=$(dev_label_for_mac "$mac" "$host" "" "")
        # Update cache if label informative
        if [ -n "$cur_label" ]; then
            grep -v "^$mac " "$NAMES_CACHE" 2>/dev/null > "$NAMES_CACHE.tmp" || true
            mv -f "$NAMES_CACHE.tmp" "$NAMES_CACHE" 2>/dev/null
            echo "$mac $cur_label" >> "$NAMES_CACHE"
        fi
    done < "$DHCP_LEASES"
}

case "${1:-scan-leases}" in
    identify)
        shift
        dev_label_for_mac "$@"
        ;;
    is-random)
        shift
        if dev_is_random_mac "$1"; then echo "random"; else echo "hardware"; fi
        ;;
    oui)
        shift
        dev_oui_vendor "$1"
        ;;
    os)
        shift
        dev_infer_os "${1:-}" "${2:-}" "${3:-}"
        ;;
    scan-leases)
        dev_scan_leases
        ;;
    *)
        echo "usage: device-identifier.sh {identify|is-random|oui|os|scan-leases}"
        exit 1
        ;;
esac
