#!/bin/sh
# probe-service.sh — one probing budget for Link / PassWall / VPS origin.
# Unifies 7 probe isolates (generate_204 vs instagram vs 1.1.1.1 vs ipify with
# 5 timeouts) into ProbeService.check(profile) with ProbeProfile per context.
# Adding a via_x28 node no longer means editing 3 probe lists.
#
# Canonical copy: router/x28/probe-service.sh — deploys to /data/proxy/probe-service.sh
# Test seam: PROBE_URL, PROBE_TIMEOUT, PROBE_SOCKS, and per-profile overrides.

PROBE_URL="${PROBE_URL:-https://www.gstatic.com/generate_204}"
PROBE_FALLBACK_URL="${PROBE_FALLBACK_URL:-http://cp.cloudflare.com/generate_204}"
PROBE_TIMEOUT="${PROBE_TIMEOUT:-5}"

DEFAULT_SOCKS="192.168.70.1:1080"
[ -f /etc/sing-box/config.json ] && DEFAULT_SOCKS="127.0.0.1:1080"
PROBE_SOCKS="${PROBE_SOCKS:-$DEFAULT_SOCKS}"

# ProbeProfile: profile → url/timeout/socks. Env-overridable per profile so tests
# can point at fixtures without patching the file.
probe_profile_get() {
    local profile="$1" var_prefix
    case "$profile" in
        link)     var_prefix="LINK" ;;
        passwall) var_prefix="PASSWALL" ;;
        vps)      var_prefix="VPS"; echo "${VPS_PROBE_URL:-http://85.121.124.158:2095/app/api/server/status}|${VPS_PROBE_TIMEOUT:-10}|"; return ;;
        *)        echo "$PROBE_URL|$PROBE_TIMEOUT|$PROBE_SOCKS"; return ;;
    esac
    eval "url=\"\${${var_prefix}_PROBE_URL:-\$PROBE_URL}\""
    eval "timeout=\"\${${var_prefix}_PROBE_TIMEOUT:-\$PROBE_TIMEOUT}\""
    eval "socks=\"\${${var_prefix}_PROBE_SOCKS:-\$PROBE_SOCKS}\""
    printf '%s|%s|%s' "$url" "$timeout" "$socks"
}

_check_endpoint() {  # _check_endpoint <url> <timeout> [socks]
    local url="$1" timeout="$2" socks="${3:-}" code proxy_arg=""
    [ -n "$socks" ] && proxy_arg="-x socks5h://$socks"
    code=$(curl -sS -m "$timeout" $proxy_arg -o /dev/null -w '%{http_code}' "$url" 2>/dev/null)
    case "$code" in 200|204) return 0 ;; esac
    return 1
}

# probe_check <profile> [url_override] — 0 when path alive (HTTP 200/204), else 1.
# One implementation for dns-fix:tunnel_ok, x28-vps-heal:mihomo_auto_dead,
# x28-health:proxied_path, operator-watchdog:check_data, snap.sh proxy_state.
probe_check() {
    local profile="${1:-link}" url_override="$2" spec url timeout socks
    spec=$(probe_profile_get "$profile")
    url=$(printf '%s' "$spec" | cut -d'|' -f1)
    timeout=$(printf '%s' "$spec" | cut -d'|' -f2)
    socks=$(printf '%s' "$spec" | cut -d'|' -f3)
    [ -n "$url_override" ] && url="$url_override"
    _check_endpoint "$url" "$timeout" "$socks" && return 0
    if [ -z "$url_override" ] && [ -n "$PROBE_FALLBACK_URL" ] && [ "$url" != "$PROBE_FALLBACK_URL" ]; then
        _check_endpoint "$PROBE_FALLBACK_URL" "$timeout" "$socks" && return 0
    fi
    return 1
}

# probe_check_direct — fail-open direct connectivity check with gateway ping fallback
probe_check_direct() {
    local timeout="${PROBE_TIMEOUT:-4}" gw="${PROBE_GATEWAY:-}"
    _check_endpoint "$PROBE_URL" "$timeout" && return 0
    [ -n "$PROBE_FALLBACK_URL" ] && _check_endpoint "$PROBE_FALLBACK_URL" "$timeout" && return 0
    if [ -z "$gw" ]; then
        if [ -f /etc/sing-box/config.json ]; then
            gw="192.168.70.1"
        else
            gw=$(ip route 2>/dev/null | awk '/default/ {print $3; exit}')
            [ -z "$gw" ] && gw="1.1.1.1"
        fi
    fi
    ping -c 2 -W 2 "$gw" >/dev/null 2>&1
}

# probe_check_data — direct-IP data probe (no DNS), used by watchdog/bot/status.
# Same contract as operator-watchdog check_data.
probe_check_data() {
    local code ep
    for ep in https://1.1.1.1 https://216.239.38.120; do
        code=$(curl -k -s -m 8 -o /dev/null -w '%{http_code}' "$ep" 2>/dev/null)
        case "$code" in 200|204|301|302) return 0 ;; esac
    done
    return 1
}

# probe_profile — prints current profiles for debugging
probe_profile() {
    local p
    for p in link passwall vps; do
        printf '%s: %s\n' "$p" "$(probe_profile_get "$p")"
    done
}

case "${1:-}" in
    check)
        if probe_check "${2:-link}"; then
            echo alive
            exit 0
        else
            echo dead
            exit 1
        fi
        ;;
    data)
        if probe_check_data; then
            echo alive
            exit 0
        else
            echo dead
            exit 1
        fi
        ;;
    direct)
        if probe_check_direct; then
            echo alive
            exit 0
        else
            echo dead
            exit 1
        fi
        ;;
    profiles) probe_profile ;;
esac
