#!/bin/sh
# diag-snapshot.sh — rolling runtime snapshot for crash diagnostics.
#
# Called from cron (every minute); appends the current logread window, load,
# and free memory to /etc/diag/runtime.log, bounded to keep flash small. When
# the router crashes and reboots, the boot entry in boots.log (see diag.init)
# dumps this file so the moments before the crash survive the reboot.

DIAG="${DIAG_DIR:-/etc/diag}"
LOG="$DIAG/runtime.log"
MAX_LINES="${DIAG_MAX_LINES:-3000}"

mkdir -p "$DIAG" 2>/dev/null || exit 0

{
    echo "=== $(date '+%F %T') load=$(cat /proc/loadavg 2>/dev/null) ==="
    free 2>/dev/null | awk '/Mem:/{print "mem used="$3" total="$2}'
    logread 2>/dev/null | tail -30
} >> "$LOG" 2>/dev/null

# bound the file so flash doesn't fill up
tail -n "$MAX_LINES" "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG" 2>/dev/null
