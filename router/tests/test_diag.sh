#!/bin/sh
# Unit tests: router/diag.init — the persistent reboot logger.
# Seam: source the init script (defines boot/start/stop), override the
# bootcount flags fixture, and exercise the REAL diag_bootcount_reset through a
# PATH shim for fw_setenv. No production body is ever copied into the test.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
. "$HERE/../diag.init"

PASS=0; FAIL=0
assert_eq() {  # assert_eq <desc> <expected> <actual>
    if [ "$2" = "$3" ]; then
        PASS=$((PASS+1))
    else
        FAIL=$((FAIL+1))
        echo "FAIL - $1"
        printf '  expect: [%s]\n' "$2"
        printf '  actual: [%s]\n' "$3"
    fi
}
summary() {
    echo "PASS=$PASS FAIL=$FAIL"
    [ "$FAIL" -eq 0 ]
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
DIAG="$TMP/diag"
mkdir -p "$DIAG"

# PATH shim: records every fw_setenv invocation so the real reset function's
# behaviour is observable without touching the router.
shim="$TMP/shim"; mkdir -p "$shim"
SHIM_LOG="$TMP/fw_setenv.log"; export SHIM_LOG
: > "$SHIM_LOG"
cat > "$shim/fw_setenv" <<'EOF'
#!/bin/sh
echo "fw_setenv $*" >> "$SHIM_LOG"
exit 0
EOF
chmod +x "$shim/fw_setenv"
PATH="$shim:$PATH"

# Fixture: a climbed counter block (what the router showed before the reset).
diag_bootcount_flags() { echo "flag_try_sys1_failed=21
flag_try_sys2_failed=8"; }

# A prior clean shutdown marker (uptime-before) must be consumed.
echo "15:00:53 up 10 min, load average: 0.45, 0.53, 0.32" > "$DIAG/uptime-before"
touch "$DIAG/clean-shutdown"

boot

entry=$(cat "$DIAG/boots.log")
assert_eq "boot: entry written" "1" "$(grep -c '=== BOOT' "$DIAG/boots.log")"
assert_eq "boot: clean marker read" "1" "$(echo "$entry" | grep -c 'previous_shutdown=clean')"
assert_eq "boot: uptime-before captured" "1" "$(echo "$entry" | grep -c 'up 10 min')"
assert_eq "boot: bootcount flags captured" "1" "$(echo "$entry" | grep -c 'bootcount_before=flag_try_sys1_failed=21 flag_try_sys2_failed=8')"
assert_eq "boot: no trailing space in bootcount line" "1" "$(echo "$entry" | grep -c 'bootcount_before=.*[^ ]$')"
assert_eq "boot: marker consumed" "0" "$(ls "$DIAG/clean-shutdown" 2>/dev/null | wc -l)"
assert_eq "boot: reset ran via shim" "1" "$(grep -c 'flag_try_sys1_failed 0' "$SHIM_LOG")"
assert_eq "boot: both counters reset" "1" "$(grep -c 'flag_try_sys2_failed 0' "$SHIM_LOG")"

# CRASH case: no clean marker -> previous_shutdown=CRASH_OR_POWER_LOSS.
rm -f "$DIAG/boots.log"
boot
entry=$(cat "$DIAG/boots.log")
assert_eq "crash: marker absent recorded" "1" "$(echo "$entry" | grep -c 'previous_shutdown=CRASH_OR_POWER_LOSS')"

summary
