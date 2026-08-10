#!/bin/sh
# Start the interactive bot if not already running + heartbeat watchdog
# Cron runs this every minute. Checks PID liveness AND heartbeat freshness.
PIDF=/tmp/botcmd.pid
HB=/tmp/botcmd.hb
NOW=$(date +%s)

if [ -f "$PIDF" ]; then
    pid=$(cat "$PIDF" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        # Process is alive — check heartbeat (Q7: 120s threshold)
        if [ -f "$HB" ]; then
            hb=$(cat "$HB" 2>/dev/null || echo 0)
            if [ $(( NOW - hb )) -le 120 ]; then
                exit 0  # alive and fresh — nothing to do
            fi
            # Heartbeat stale → wedge detected, kill and respawn
            logger -t botcmd-start "watchdog: PID $pid stale (hb age $((NOW-hb))s), killing"
            kill "$pid" 2>/dev/null; sleep 1
            kill -9 "$pid" 2>/dev/null; sleep 1
        else
            # No heartbeat file yet — either pre-heartbeat version or just started.
            # Don't kill; wait for next cron cycle.
            exit 0
        fi
    fi
    # PID dead (or just killed) — clean up
    rm -f "$PIDF"
    rmdir /tmp/botcmd.lock 2>/dev/null
fi

rm -f "$HB"
nohup /root/botcmd.sh >> /tmp/botcmd.log 2>&1 &
