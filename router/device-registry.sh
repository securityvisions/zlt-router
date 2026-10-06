#!/bin/sh
# /root/device-registry.sh — Deep Device Registry, Naming & Trust Module
# Single source of truth for device resolution, naming precedence,
# Device Trust Level domain modeling, watchlist tracking, and lease metadata.
#
# Device Trust Levels (CONTEXT.md):
#   - Blocked: Explicitly quarantined/blocked via nftables drop
#   - Trusted: Static admin infrastructure or exempt devices
#   - Known: Named or approved household devices
#   - Guest: Isolated guest network devices (192.168.2.x)
#   - Unknown: Unrecognized devices pending approval

# Dynamic path getters (allows test runners and callers to override paths after sourcing)
dev_reg_un_path() { echo "${DEV_REG_USER_NAMES:-${RA_USER_NAMES:-${USER_NAMES:-/etc/usage-log/user-names}}}"; }
dev_reg_dl_path() { echo "${DEV_REG_DHCP_LEASES:-${RA_DHCP_LEASES:-${DHCP_LEASES:-/tmp/dhcp.leases}}}"; }
dev_reg_wl_path() { echo "${DEV_REG_WATCHLIST:-${RA_WATCHLIST:-${WATCHLIST:-/etc/usage-log/watchlist}}}"; }
dev_reg_nc_path() { echo "${DEV_REG_NAMES_CACHE:-${RA_NAMES_CACHE:-${NAMES_CACHE:-/etc/usage-log/names}}}"; }
dev_reg_al_path() { echo "${DEV_REG_ALLOW:-${QUARANTINE_ALLOW:-/etc/quarantine-allow}}"; }
dev_reg_ex_path() { echo "${DEV_REG_EXEMPT:-${QUARANTINE_EXEMPT:-/etc/quarantine-exempt}}"; }
dev_reg_bl_path() { echo "${DEV_REG_BLOCKED:-${QUARANTINE_BLOCKED:-/etc/quarantine-blocked}}"; }
dev_reg_fl_path() { echo "${DEV_REG_FLAG:-${QUARANTINE_FLAG:-/etc/quarantine-enabled}}"; }
dev_reg_tr_path() { echo "${DEV_REG_TRUSTED:-/etc/usage-log/trusted-devices}"; }

# Normalize MAC to lowercase
dev_reg_norm_mac() {
    echo "$1" | tr 'A-F' 'a-f'
}

# Resolve display name for MAC:
# Priority 1: User-assigned name (/etc/usage-log/user-names)
# Priority 2: Active DHCP lease hostname (/tmp/dhcp.leases)
# Priority 3: Historical names cache (/tmp/device-names.cache)
# Fallback:   "Unknown-XX:XX:XX"
dev_reg_name() {
    local mac name un dl nc
    mac=$(dev_reg_norm_mac "$1")
    [ -z "$mac" ] && return 1

    un=$(dev_reg_un_path)
    dl=$(dev_reg_dl_path)
    nc=$(dev_reg_nc_path)

    # 1. User override
    name=$(awk -v m="$mac" 'tolower($1)==m {print $2; exit}' "$un" 2>/dev/null)
    if [ -n "$name" ]; then echo "$name"; return 0; fi

    # 2. DHCP lease
    name=$(awk -v m="$mac" 'tolower($2)==m && $4!="*" {print $4; exit}' "$dl" 2>/dev/null)
    if [ -n "$name" ]; then echo "$name"; return 0; fi

    # 3. Cache
    name=$(awk -v m="$mac" 'tolower($1)==m {print $2; exit}' "$nc" 2>/dev/null)
    if [ -n "$name" ]; then echo "$name"; return 0; fi

    # 4. Deep Device Identifier (OUI + Option 55/60 heuristics)
    for _di in "/root/device-identifier.sh" "/usr/sbin/device-identifier.sh" "$(dirname "$0")/device-identifier.sh"; do
        if [ -x "$_di" ]; then
            name=$("$_di" identify "$mac" 2>/dev/null)
            if [ -n "$name" ] && [ "$name" != "Unknown" ]; then echo "$name"; return 0; fi
            break
        fi
    done

    # Fallback
    echo "Unknown-$(echo "$mac" | cut -c1-8)"
}

# Check if MAC is watched (1=watched, 0=not watched)
dev_reg_is_watched() {
    local mac wl
    mac=$(dev_reg_norm_mac "$1")
    wl=$(dev_reg_wl_path)
    awk -v m="$mac" 'tolower($1)==m {found=1; exit} END{if(found) exit 0; else exit 1}' "$wl" 2>/dev/null && echo "1" || echo "0"
}

# Resolve Device Trust Level for MAC: Trusted | Known | Guest | Unknown | Blocked
dev_reg_trust_level() {
    local mac bl fl al ex tr un dl ip
    mac=$(dev_reg_norm_mac "$1")
    [ -z "$mac" ] && { echo "Unknown"; return; }

    bl=$(dev_reg_bl_path)
    fl=$(dev_reg_fl_path)
    al=$(dev_reg_al_path)
    ex=$(dev_reg_ex_path)
    tr=$(dev_reg_tr_path)
    un=$(dev_reg_un_path)
    dl=$(dev_reg_dl_path)

    # 1. Explicitly Blocked
    if [ -f "$bl" ] && grep -qxi "$mac" "$bl" 2>/dev/null; then
        echo "Blocked"; return
    fi

    # 2. Quarantine Mode Active & Not Approved
    if [ -f "$fl" ]; then
        local approved=0
        [ -f "$al" ] && grep -qxi "$mac" "$al" 2>/dev/null && approved=1
        [ -f "$ex" ] && grep -qxi "$mac" "$ex" 2>/dev/null && approved=1
        [ -f "$tr" ] && grep -qxi "$mac" "$tr" 2>/dev/null && approved=1
        if [ "$approved" = "0" ]; then
            echo "Blocked"; return
        fi
    fi

    # 3. Trusted (exempt infrastructure or explicitly trusted)
    if [ -f "$ex" ] && grep -qxi "$mac" "$ex" 2>/dev/null; then
        echo "Trusted"; return
    fi
    if [ -f "$tr" ] && grep -qxi "$mac" "$tr" 2>/dev/null; then
        echo "Trusted"; return
    fi

    # 4. Guest subnet detection (192.168.2.x)
    ip=$(awk -v m="$mac" 'tolower($2)==m {print $3; exit}' "$dl" 2>/dev/null)
    case "$ip" in
        192.168.2.*) echo "Guest"; return ;;
    esac

    # 5. Known (has user-assigned name or in quarantine allow)
    if [ -f "$un" ] && grep -qxi "^$mac[[:space:]].*" "$un" 2>/dev/null; then
        echo "Known"; return
    fi
    if [ -f "$al" ] && grep -qxi "$mac" "$al" 2>/dev/null; then
        echo "Known"; return
    fi

    # 6. Fallback: Unknown
    echo "Unknown"
}

# Set Device Trust Level atomically across backing files
dev_reg_set_trust() {
    local mac level bl al ex tr tmp
    mac=$(dev_reg_norm_mac "$1")
    level="$2"
    [ -z "$mac" ] && return 1

    bl=$(dev_reg_bl_path)
    al=$(dev_reg_al_path)
    ex=$(dev_reg_ex_path)
    tr=$(dev_reg_tr_path)

    # Clean existing records in all trust stores
    for f in "$bl" "$al" "$ex" "$tr"; do
        if [ -f "$f" ]; then
            mkdir -p "$(dirname "$f")" 2>/dev/null || true
            tmp="${f}.tmp.$$"
            grep -vxi "$mac" "$f" 2>/dev/null > "$tmp" || true
            mv -f "$tmp" "$f"
        fi
    done

    # Write new assignment
    case "$level" in
        Blocked|blocked)
            mkdir -p "$(dirname "$bl")" 2>/dev/null || true
            echo "$mac" >> "$bl"
            dev_reg_enforce_mac "$mac" "drop"
            ;;
        Trusted|trusted)
            mkdir -p "$(dirname "$tr")" 2>/dev/null || true
            echo "$mac" >> "$tr"
            dev_reg_enforce_mac "$mac" "allow"
            ;;
        Known|known|Approved|approved)
            mkdir -p "$(dirname "$al")" 2>/dev/null || true
            echo "$mac" >> "$al"
            dev_reg_enforce_mac "$mac" "allow"
            ;;
        *)
            dev_reg_enforce_mac "$mac" "allow"
            ;;
    esac
}

# Get detailed record: mac|name|source|ip|hostname|watched|trust_level
dev_reg_get() {
    local mac name src ip hostname watched trust u l c un dl nc
    mac=$(dev_reg_norm_mac "$1")
    [ -z "$mac" ] && return 1

    un=$(dev_reg_un_path)
    dl=$(dev_reg_dl_path)
    nc=$(dev_reg_nc_path)

    src="unknown"
    u=$(awk -v m="$mac" 'tolower($1)==m {print $2; exit}' "$un" 2>/dev/null)
    if [ -n "$u" ]; then
        name="$u"
        src="user-names"
    else
        l=$(awk -v m="$mac" 'tolower($2)==m && $4!="*" {print $4; exit}' "$dl" 2>/dev/null)
        if [ -n "$l" ]; then
            name="$l"
            src="lease"
        else
            c=$(awk -v m="$mac" 'tolower($1)==m {print $2; exit}' "$nc" 2>/dev/null)
            if [ -n "$c" ]; then
                name="$c"
                src="cache"
            else
                name="Unknown-$(echo "$mac" | cut -c1-8)"
            fi
        fi
    fi

    # Read DHCP details
    ip=$(awk -v m="$mac" 'tolower($2)==m {print $3; exit}' "$dl" 2>/dev/null)
    hostname=$(awk -v m="$mac" 'tolower($2)==m && $4!="*" {print $4; exit}' "$dl" 2>/dev/null)
    watched=$(dev_reg_is_watched "$mac")
    trust=$(dev_reg_trust_level "$mac")

    if [ "${2:-}" = "full" ]; then
        echo "$mac|$name|$src|$ip|$hostname|$watched|$trust"
    else
        echo "$mac|$name|$src|$ip|$hostname|$watched"
    fi
}

dev_reg_record() {
    dev_reg_get "$1" "full"
}

# Set/update user-assigned name for MAC atomically
dev_reg_rename() {
    local mac name tmp un
    mac=$(dev_reg_norm_mac "$1")
    name=$(echo "$2" | tr -d ' \t\n\r|"')
    [ -z "$mac" ] || [ -z "$name" ] && return 1

    un=$(dev_reg_un_path)
    mkdir -p "$(dirname "$un")" 2>/dev/null
    tmp="${un}.tmp.$$"
    grep -iv "^$mac[[:space:]]" "$un" 2>/dev/null > "$tmp" || true
    echo "$mac $name" >> "$tmp"
    mv -f "$tmp" "$un"
}

# Toggle watchlist membership (1=add, 0=remove)
dev_reg_set_watch() {
    local mac action tmp wl
    mac=$(dev_reg_norm_mac "$1")
    action="$2"
    [ -z "$mac" ] && return 1

    wl=$(dev_reg_wl_path)
    mkdir -p "$(dirname "$wl")" 2>/dev/null
    tmp="${wl}.tmp.$$"
    grep -iv "^$mac$" "$wl" 2>/dev/null > "$tmp" || true
    if [ "$action" = "1" ] || [ "$action" = "true" ]; then
        echo "$mac" >> "$tmp"
    fi
    mv -f "$tmp" "$wl"
}

# Enforce firewall rule for single MAC
dev_reg_enforce_mac() {
    local mac action
    mac="$1"
    action="$2" # drop | allow
    if ! command -v nft >/dev/null 2>&1; then return 0; fi

    if [ "$action" = "drop" ]; then
        if ! nft -a list chain inet fw4 forward 2>/dev/null | grep -q "ether saddr $mac drop"; then
            nft -a add rule inet fw4 forward ether saddr "$mac" drop 2>/dev/null || true
        fi
    else
        nft -a list chain inet fw4 forward 2>/dev/null |
            awk -v m="$mac" '$0 ~ ("ether saddr " m " drop") {
                for (i = 1; i <= NF; i++) if ($i == "handle") print $(i + 1)
            }' |
            while read -r h; do
                [ -n "$h" ] && nft delete rule inet fw4 forward handle "$h" 2>/dev/null || true
            done
    fi
}

# Synchronize firewall rules for all devices
dev_reg_enforce_all() {
    local dl mac trust
    dl=$(dev_reg_dl_path)
    [ -f "$dl" ] || return 0

    awk '{print $2}' "$dl" | sort -u | while read -r mac; do
        [ -z "$mac" ] && continue
        trust=$(dev_reg_trust_level "$mac")
        if [ "$trust" = "Blocked" ]; then
            dev_reg_enforce_mac "$mac" "drop"
        else
            dev_reg_enforce_mac "$mac" "allow"
        fi
    done
}
