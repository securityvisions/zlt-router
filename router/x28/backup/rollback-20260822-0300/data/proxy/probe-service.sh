#!/bin/sh
# probe-service.sh — one probing budget for Link / PassWall / VPS origin.
# Unifies 7 probe isolates (generate_204 vs instagram vs 1.1.1.1 vs ipify with
# 5 timeouts) into ProbeService.check(profile) with ProbeProfile per context.
# Adding a via_x28 node no longer means editing 3 probe lists.
#
# Canonical copy: router/x28/probe-service.sh — deploys to /data/proxy/probe-service.sh
# Test seam: PROBE_URL, PROBE_TIMEOUT, PROBE_SOCKS, and per-profile overrides.

PROBE_URL="${PROBE_URL:-https://www.gstatic.com/generate_204}"
PROBE_TIMEOUT="${PROBE_TIMEOUT:-5}"
PROBE_SOCKS="${PROBE_SOCKS:-127.0.0.1:1070}"

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

# probe_check <profile> [url_override] — 0 when path alive (HTTP 200/204), else 1.
# One implementation for dns-fix:tunnel_ok, x28-vps-heal:mihomo_auto_dead,
# x28-health:proxied_path, operator-watchdog:check_data, snap.sh proxy_state.
probe_check() {
    local profile="${1:-link}" url_override="$2" spec url timeout socks code
    spec=$(probe_profile_get "$profile")
    url=$(printf '%s' "$spec" | cut -d'|' -f1)
    timeout=$(printf '%s' "$spec" | cut -d'|' -f2)
    socks=$(printf '%s' "$spec" | cut -d'|' -f3)
    [ -n "$url_override" ] && url="$url_override"
    if [ -n "$socks" ]; then
        code=$(curl -sS -m "$timeout" --socks5 "$socks" -o /dev/null -w '%{http_code}' "$url" 2>/dev/null)
    else
        code=$(curl -sS -m "$timeout" -o /dev/null -w '%{http_code}' "$url" 2>/dev/null)
    fi
    case "$code" in 200|204) return 0 ;; *) return 1 ;; esac
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
    check) probe_check "${2:-link}" && echo alive || echo dead ;;
    data)  probe_check_data && echo alive || echo dead ;;
    profiles) probe_profile ;;
esac
