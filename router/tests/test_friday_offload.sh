#!/bin/sh
# Unit tests: router/friday-offload.sh — queue run + announce gating.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
F="$HERE/../friday-offload.sh"
export HN_LIB="$HERE/../hnlib.sh"

PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
ck() {  # ck <desc> <expected> <actual>
    if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else
        FAIL=$((FAIL+1)); echo "FAIL - $1: expect [$2] actual [$3]"; fi
}

# A queue with two successful jobs and one failing job.
mkdir -p "$TMP/q"
printf 'echo hello > %s/out1\nfalse\necho world > %s/out2\n' "$TMP" "$TMP" > "$TMP/q/jobs"
out=$(sh "$F" --run "$TMP/q" "$TMP/log")
ck "runs ok jobs" "offload: ran 2 job(s)" "$out"
ck "ok job executed" "hello" "$(cat "$TMP/out1" 2>/dev/null)"
ck "ok job 2 executed" "world" "$(cat "$TMP/out2" 2>/dev/null)"
ck "failing job stays queued" "false" "$(cat "$TMP/q/jobs" 2>/dev/null)"

# Empty queue is a no-op.
out=$(sh "$F" --run "$TMP/empty" "$TMP/log2")
ck "empty queue no-op" "offload: queue empty" "$out"

# Enqueue appends a job.
out=$(OFFLOAD_QUEUE="$TMP/q2" sh "$F" --enqueue "/root/backup.sh")
ck "enqueue reports" "queued for Friday: /root/backup.sh" "$out"
ck "enqueue persisted" "/root/backup.sh" "$(cat "$TMP/q2/jobs" 2>/dev/null)"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
