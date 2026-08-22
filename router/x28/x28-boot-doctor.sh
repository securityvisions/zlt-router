#!/bin/sh
# x28-boot-doctor.sh — post-boot convergence verify + repair (Boot Doctor).
# ~90 s after boot: run the health gate. GREEN → one quiet "verified" card.
# RED → execute the repair plan from hn_boot_repair_plan in order
# (rules → dns → proxy → watchdog), re-check, and send ONE verdict card.
# One-shot by design: never loops, safe under procd.
#
# Env seams for tests: BOOT_DELAY, BOOT_DRYRUN=1 (print plan, no actions,
# no card), HEALTH_CMD (default the real gate), NOTIFY (0 disables cards).
set -u

HN_LIB="${HN_LIB:-/root/hnlib.sh}"
[ -f "$HN_LIB" ] || HN_LIB="/data/proxy/hnlib.sh"
[ -f "$HN_LIB" ] && . "$HN_LIB"

BOOT_DELAY="${BOOT_DELAY:-90}"
HEALTH_CMD="${HEALTH_CMD:-sh /data/proxy/x28-health.sh}"
NOTIFY="${BOOT_NOTIFY:-1}"

bd_card() {
    [ "$NOTIFY" = "1" ] || return 0
    sh /data/proxy/tg-notify.sh "$1" "$2" >/dev/null 2>&1 || true
}

repair_action() {  # repair_action <action> — executes one plan step
    case "$1" in
        rules)    sh /data/proxy/tproxy-fixed-enable.sh >/dev/null 2>&1 || true ;;
        dns)      sh /data/proxy/dns-fix.sh             >/dev/null 2>&1 || true ;;
        proxy)    /etc/init.d/x28proxy restart          >/dev/null 2>&1 || true ;;
        watchdog) /etc/init.d/x28-watchdog restart      >/dev/null 2>&1 || true ;;
    esac
}

boot_doctor() {
    sleep "$BOOT_DELAY"
    health=$($HEALTH_CMD 2>/dev/null)
    plan=$(hn_boot_repair_plan "$health")

    if [ -z "$plan" ]; then
        [ "$BOOT_DRYRUN" = "1" ] && { echo "plan: none (GREEN)"; return 0; }
        bd_card "✅ Boot verified" "health gate GREEN ${BOOT_DELAY}s after boot — no repairs needed"
        return 0
    fi

    if [ "$BOOT_DRYRUN" = "1" ]; then
        echo "plan: $(printf '%s' "$plan" | tr '\n' ',')"
        return 0
    fi

    repaired=""
    for step in $plan; do
        repair_action "$step"
        repaired="$repaired $step"
        sleep 3
    done

    health2=$($HEALTH_CMD 2>/dev/null)
    if printf '%s\n' "$health2" | grep -q 'HEALTH: GREEN'; then
        bd_card "🩺 Boot doctor — repaired" "was RED; applied:${repaired}
now GREEN"
    else
        fails=$(printf '%s\n' "$health2" | grep -c '^FAIL ' || true)
        bd_card "🩺 Boot doctor — STILL RED" "applied:${repaired}
${fails} check(s) still failing; watchdog/heal loops continue"
    fi
}

case "${1:-run}" in
    run) boot_doctor ;;
    plan) health=$($HEALTH_CMD 2>/dev/null); hn_boot_repair_plan "$health" ;;
    *) echo "usage: x28-boot-doctor.sh [run|plan]" >&2; exit 2 ;;
esac
