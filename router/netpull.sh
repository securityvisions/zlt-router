#!/bin/sh
# netpull — device-canonical config backup: status/diff + pull.
# ADR-0007: the DEVICE is canonical; this tool NEVER pushes to a device.
#   netpull status         — table: repo↔device divergence per manifest entry
#   netpull pull <name>    — device → repo for one manifest entry
#   netpull pull all       — device → repo for every entry
#   netpull manifest       — print the manifest (owner|name|device_path|repo_path|host)
#
# Manifest owner semantics (ADR-0007 §5):
#   device — device-owned config; repo copy is a backup (mihomo-config, dns-fix…)
#   repo   — repo-authored tool deployed to the device (probe-service, axproxy-nft…)
# Both directions show up in `status`; both are pull-able. Nothing here pushes.
#
# Env seams (test-first, same pattern as probe-service.sh):
#   NETPULL_AX   — command string reaching AX3000T (default: sshpass+ssh)
#   NETPULL_X28  — command string reaching X28
#   NETPULL_ROOT — repo root override (tests: a temp dir)

set -u

NETPULL_ROOT="${NETPULL_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}"
NETPULL_AX="${NETPULL_AX:-sshpass -p xirouter123 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@192.168.1.1}"
NETPULL_X28="${NETPULL_X28:-sshpass -p G5K0utrzATYX ssh -o StrictHostKeyChecking=no -o HostKeyAlgorithms=+ssh-rsa -o ConnectTimeout=15 root@192.168.70.1}"

# name|owner|device_path|repo_path(relative to NETPULL_ROOT)|host
# host: ax = AX3000T, x28 = X28
manifest() {
    cat << 'M_EOF'
mihomo-config|device|/data/proxy/mihomo/config.yaml|router/x28/mihomo-config.yaml|x28
dns-fix|device|/data/proxy/dns-fix.sh|router/x28/dns-fix.sh|x28
operator-watchdog|device|/data/proxy/operator-watchdog.sh|router/x28/operator-watchdog.sh|x28
x28-vps-heal|device|/data/proxy/x28-vps-heal.sh|router/x28/x28-vps-heal.sh|x28
probe-service|repo|/data/proxy/probe-service.sh|router/x28/probe-service.sh|x28
tproxy-fixed-enable|repo|/data/proxy/tproxy-fixed-enable.sh|router/x28/tproxy-fixed-enable.sh|x28
linkstate|repo|/data/proxy/linkstate.sh|router/x28/linkstate.sh|x28
probe-service-ax|repo|/usr/sbin/probe-service.sh|router/x28/probe-service.sh|ax
proxy-watchdog|device|/usr/sbin/proxy-watchdog.sh|router/proxy-watchdog.sh|ax
axproxy-nft|repo|/etc/axproxy.nft|router/axproxy.nft|ax
axproxy-sh|repo|/etc/axproxy.sh|router/axproxy.sh|ax
sing-box-config|repo|/etc/sing-box/config.json|router/sing-box-config.json|ax
rc-local|device|/etc/rc.local|router/rc.local|ax
M_EOF
}

repo_hash() {  # repo_hash <repo_rel_path> — prints md5 or MISSING
    local p="$NETPULL_ROOT/$1"
    [ -f "$p" ] && md5sum "$p" | awk '{print $1}' || echo MISSING
}

remote_md5s() {  # remote_md5s <host> <out_tmp> <paths_tmp>
    local host="$1" out="$2" tmp="$3" cmd paths
    [ "$host" = "ax" ] && cmd="$NETPULL_AX" || cmd="$NETPULL_X28"
    # manifest device paths contain no spaces -> safe to build args directly.
    # (AX3000T busybox lacks xargs, so paths-as-args it is.)
    paths=$(manifest | awk -F'|' -v H="$host" '$5==H{printf "%s ", $3}')
    [ -n "$paths" ] || { : > "$out"; return 0; }
    eval "\$cmd md5sum \$paths 2>/dev/null" > "$out"
}

cmd_status() {
    # One batched ssh per router: collect all device hashes up front.
    remote_md5s ax /tmp/netpull.ax.$$ /tmp/netpull.paths.ax.$$
    remote_md5s x28 /tmp/netpull.x28.$$ /tmp/netpull.paths.x28.$$

    printf '%-20s %-7s %-10s %s\n' 'NAME' 'OWNER' 'STATE' 'NOTE'
    printf '%-20s %-7s %-10s %s\n' '----' '-----' '-----' '----'
    manifest | while IFS='|' read -r name owner dev rp host; do
        dh=$(awk -v d="$dev" '$2==d{print $1; exit}' /tmp/netpull.ax.$$ /tmp/netpull.x28.$$)
        [ -n "$dh" ] || dh=MISSING
        rh=$(repo_hash "$rp")
        if [ "$dh" = "MISSING" ]; then
            printf '%-20s %-7s %-10s %s\n' "$name" "$owner" 'NO-DEVICE' "$dev not found on router"
        elif [ "$rh" = "MISSING" ]; then
            printf '%-20s %-7s %-10s %s\n' "$name" "$owner" 'NO-REPO' "run: netpull pull $name"
        elif [ "$dh" = "$rh" ]; then
            printf '%-20s %-7s %-10s\n' "$name" "$owner" 'match'
        else
            printf '%-20s %-7s %-10s %s\n' "$name" "$owner" 'DIVERGED' "run: netpull pull $name"
        fi
    done
    rm -f /tmp/netpull.ax.$$ /tmp/netpull.x28.$$ /tmp/netpull.paths.*.$$ 2>/dev/null
}

cmd_pull() {
    local target="${1:-all}" name owner dev rp host out
    manifest | while IFS='|' read -r name owner dev rp host; do
        [ "$target" = "all" ] || [ "$target" = "$name" ] || continue
        cmd="$NETPULL_AX"; [ "$host" = "x28" ] && cmd="$NETPULL_X28"
        out="$NETPULL_ROOT/$rp"
        mkdir -p "$(dirname "$out")" 2>/dev/null || true
        if eval "\$cmd cat \$dev 2>/dev/null" < /dev/null > "$out.netpull.tmp" && [ -s "$out.netpull.tmp" ]; then
            mv "$out.netpull.tmp" "$out"
            echo "pulled: $name -> $rp"
        else
            rm -f "$out.netpull.tmp"
            echo "FAILED: $name ($dev not readable on $host)"
        fi
    done
}

case "${1:-status}" in
    status)   cmd_status ;;
    pull)     cmd_pull "${2:-all}" ;;
    manifest) manifest ;;
    *) echo "usage: netpull [status|pull [name|all]|manifest]"; exit 2 ;;
esac
