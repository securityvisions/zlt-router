#!/usr/bin/env bash
# ==============================================================================
# VPS2 VirtFusion Auto-Boot Watchdog (Production Hardened)
#
# Monitors VPS 2 availability and triggers VirtFusion REST API boot only on
# verified, persistent failure.
#
# Resilience & Anti-Spam Protections:
# - Multi-vector probe: SSH (22), Reality (443), and ICMP ping.
# - High failure threshold (5 consecutive failed cycles).
# - Progressive exponential cooldown (10m -> 20m -> 40m).
# - Circuit Breaker / Lockout: After 3 failed boots, pauses for 2 hours to
#   prevent API spam during broad network partitions or datacenter outages.
# - Pre-flight provider checks: Aborts if VM is suspended, migrating, or backing up.
# - State recovery: Resets all failure counters upon first successful probe.
# ==============================================================================

set -euo pipefail

CONF_FILE="/etc/vps2-autoboot.conf"
if [[ -f "$CONF_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONF_FILE"
fi

# Configuration Defaults
SERVER_IP="${SERVER_IP:-5.175.234.113}"
SERVER_PORT="${SERVER_PORT:-22}"
SERVER_UUID="${SERVER_UUID:-58d29425-b1c5-4f65-911b-7a42b9df7214}"
API_BASE="${API_BASE:-https://platform.servitro.com/api}"
API_TOKEN="${API_TOKEN:-}"
FAIL_THRESHOLD="${FAIL_THRESHOLD:-5}"
BASE_COOLDOWN="${BASE_COOLDOWN_SECONDS:-600}"
MAX_BOOT_ATTEMPTS="${MAX_BOOT_ATTEMPTS:-3}"
LOCKOUT_SECONDS="${LOCKOUT_SECONDS:-7200}"
LOG_FILE="${LOG_FILE:-/var/log/vps2-autoboot.log}"

STATE_DIR="/var/run/vps2-autoboot"
mkdir -p "$STATE_DIR"
FAIL_FILE="${STATE_DIR}/fail_count"
BOOT_COUNT_FILE="${STATE_DIR}/boot_count"
COOLDOWN_UNTIL_FILE="${STATE_DIR}/cooldown_until"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg"
    if [[ -n "$LOG_FILE" ]]; then
        echo "$msg" >> "$LOG_FILE"
    fi
}

if [[ -z "$API_TOKEN" ]]; then
    log "ERROR: API_TOKEN is empty. Cannot manage VirtFusion server."
    exit 1
fi

check_port() {
    local ip="$1"
    local port="$2"
    if command -v nc >/dev/null 2>&1; then
        nc -z -w 3 "$ip" "$port" >/dev/null 2>&1
        return $?
    else
        timeout 3 bash -c "cat < /dev/null > /dev/tcp/$ip/$port" >/dev/null 2>&1
        return $?
    fi
}

check_icmp() {
    local ip="$1"
    ping -c 2 -W 2 "$ip" >/dev/null 2>&1
    return $?
}

# ------------------------------------------------------------------------------
# 1. Multi-Vector Health Probe
# ------------------------------------------------------------------------------
IS_ALIVE=0
if check_port "$SERVER_IP" "$SERVER_PORT"; then
    IS_ALIVE=1
elif check_port "$SERVER_IP" 443; then
    IS_ALIVE=1
elif check_icmp "$SERVER_IP"; then
    # Machine responds to ICMP -> host is running, network stack is up
    IS_ALIVE=1
fi

if [[ "$IS_ALIVE" -eq 1 ]]; then
    PREV_FAILS=$(cat "$FAIL_FILE" 2>/dev/null || echo 0)
    PREV_BOOTS=$(cat "$BOOT_COUNT_FILE" 2>/dev/null || echo 0)
    if [[ "$PREV_FAILS" -gt 0 || "$PREV_BOOTS" -gt 0 ]]; then
        log "RECOVERY: VPS 2 ($SERVER_IP) is responsive. Resetting failure and boot counters."
    fi
    rm -f "$FAIL_FILE" "$BOOT_COUNT_FILE" "$COOLDOWN_UNTIL_FILE"
    exit 0
fi

# ------------------------------------------------------------------------------
# 2. Record Probe Failure
# ------------------------------------------------------------------------------
FAILS=1
if [[ -f "$FAIL_FILE" ]]; then
    FAILS=$(($(cat "$FAIL_FILE" 2>/dev/null || echo 0) + 1))
fi
echo "$FAILS" > "$FAIL_FILE"

log "WARNING: VPS 2 ($SERVER_IP) probe failed (attempt $FAILS/$FAIL_THRESHOLD)."

if [[ "$FAILS" -lt "$FAIL_THRESHOLD" ]]; then
    exit 0
fi

# ------------------------------------------------------------------------------
# 3. Check Cooldown / Circuit Breaker Lockout
# ------------------------------------------------------------------------------
NOW=$(date +%s)
if [[ -f "$COOLDOWN_UNTIL_FILE" ]]; then
    COOLDOWN_UNTIL=$(cat "$COOLDOWN_UNTIL_FILE" 2>/dev/null || echo 0)
    if [[ "$NOW" -lt "$COOLDOWN_UNTIL" ]]; then
        REMAINING=$((COOLDOWN_UNTIL - NOW))
        log "NOTICE: Cooldown/Lockout active (${REMAINING}s remaining). Halting boot actions."
        exit 0
    fi
fi

CURRENT_BOOTS=0
if [[ -f "$BOOT_COUNT_FILE" ]]; then
    CURRENT_BOOTS=$(cat "$BOOT_COUNT_FILE" 2>/dev/null || echo 0)
fi

# If we reached the maximum boot limit and server is still unresponsive,
# activate the Circuit Breaker Lockout (e.g. 2 hours)
if [[ "$CURRENT_BOOTS" -ge "$MAX_BOOT_ATTEMPTS" ]]; then
    LOCKOUT_UNTIL=$((NOW + LOCKOUT_SECONDS))
    echo "$LOCKOUT_UNTIL" > "$COOLDOWN_UNTIL_FILE"
    log "CRITICAL: Maximum boot attempts ($MAX_BOOT_ATTEMPTS) reached without recovery. Suspected broad network partition or hypervisor host issue. Locking out auto-boot for $((LOCKOUT_SECONDS / 60)) minutes to prevent API spam."
    exit 0
fi

# ------------------------------------------------------------------------------
# 4. Pre-Flight Provider Checks
# ------------------------------------------------------------------------------
log "ALERT: Failure threshold reached. Querying VirtFusion API for server state..."
STATUS_JSON=$(curl -s -m 10 \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Accept: application/json" \
    "${API_BASE}/server/${SERVER_UUID}" 2>/dev/null || echo "")

if [[ -n "$STATUS_JSON" ]] && command -v jq >/dev/null 2>&1; then
    IS_SUSPENDED=$(echo "$STATUS_JSON" | jq -r '.data.suspended // false' 2>/dev/null || echo "false")
    IS_MIGRATING=$(echo "$STATUS_JSON" | jq -r '.data.migrating // false' 2>/dev/null || echo "false")
    IS_BACKUP=$(echo "$STATUS_JSON" | jq -r '.data.backupCreating // false' 2>/dev/null || echo "false")
    IS_DELETING=$(echo "$STATUS_JSON" | jq -r '.data.deleting // false' 2>/dev/null || echo "false")

    if [[ "$IS_SUSPENDED" == "true" ]]; then
        log "ABORT: Server is marked as SUSPENDED in VirtFusion. Skipping boot."
        exit 0
    fi
    if [[ "$IS_MIGRATING" == "true" ]]; then
        log "ABORT: Server is currently MIGRATING. Skipping boot."
        exit 0
    fi
    if [[ "$IS_BACKUP" == "true" ]]; then
        log "ABORT: Server BACKUP is currently being created. Skipping boot."
        exit 0
    fi
    if [[ "$IS_DELETING" == "true" ]]; then
        log "ABORT: Server is marked for DELETION. Skipping boot."
        exit 0
    fi
fi

# ------------------------------------------------------------------------------
# 5. Trigger Boot with Progressive Exponential Cooldown
# ------------------------------------------------------------------------------
NEXT_BOOT_NUM=$((CURRENT_BOOTS + 1))
echo "$NEXT_BOOT_NUM" > "$BOOT_COUNT_FILE"

# Progressive cooldown: Attempt 1 -> BASE (10m), Attempt 2 -> 2x BASE (20m), Attempt 3 -> 4x BASE (40m)
MULTIPLIER=1
for ((i = 1; i < NEXT_BOOT_NUM; i++)); do
    MULTIPLIER=$((MULTIPLIER * 2))
done
THIS_COOLDOWN=$((BASE_COOLDOWN * MULTIPLIER))
COOLDOWN_UNTIL=$((NOW + THIS_COOLDOWN))
echo "$COOLDOWN_UNTIL" > "$COOLDOWN_UNTIL_FILE"

log "ACTION: Issuing POST boot request to VirtFusion API (Attempt $NEXT_BOOT_NUM/$MAX_BOOT_ATTEMPTS, next cooldown: $((THIS_COOLDOWN / 60))m)..."
BOOT_RESP=$(curl -s -m 15 -X POST \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Accept: application/json" \
    "${API_BASE}/server/${SERVER_UUID}/boot" 2>/dev/null || echo "Request Failed")

log "ACTION RESULT: $BOOT_RESP"

# Reset fail counter so we only count new failures after cooldown expires
rm -f "$FAIL_FILE"
