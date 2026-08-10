#!/bin/sh
# Shared test harness: sources the canonical botlib and defines assertions.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
# Prefer a local botlib (for on-router testing); fall back to the repo canonical copy
if [ -f "$HERE/botlib.sh" ]; then
    . "$HERE/botlib.sh"
else
    . "$HERE/../../../router/botlib.sh"
fi
unset HERE

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
assert_empty() {  # assert_empty <desc> <actual>
    if [ -z "$2" ]; then PASS=$((PASS+1)); else
        FAIL=$((FAIL+1)); echo "FAIL - $1 (want empty, got [$2])"; fi
}
summary() {
    echo "PASS=$PASS FAIL=$FAIL"
    [ "$FAIL" -eq 0 ]
}