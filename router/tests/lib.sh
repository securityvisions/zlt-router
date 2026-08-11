#!/bin/sh
# Shared test harness for the Router API. Sources the canonical routerapi_lib.sh
# and defines assertions. Usage: . ./lib.sh  (from a test_*.sh in this dir)
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
RA_LIB="$HERE/../routerapi_lib.sh"

# Prefer a local copy (for on-router testing); fall back to the repo canonical copy
if [ -f "$HERE/routerapi_lib.sh" ]; then
    RA_LIB="$HERE/routerapi_lib.sh"
fi
. "$RA_LIB"

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
assert_json_eq() {  # assert_json_eq <desc> <expected> <actual>  (jq-canonicalized, numbers normalized)
    local e a
    # Strict parse gate: jq tolerates trailing garbage ("{"a":1}}"), but the app's
    # JSON decoder does not — so reject anything that isn't strictly valid JSON.
    if ! printf '%s' "$3" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
        FAIL=$((FAIL+1))
        echo "FAIL - $1"
        echo '  actual is NOT strictly valid JSON:'
        echo "$3"
        return
    fi
    e=$(printf '%s' "$2" | jq -cS 'walk(if type=="number" then .+0 else . end)' 2>/dev/null)
    a=$(printf '%s' "$3" | jq -cS 'walk(if type=="number" then .+0 else . end)' 2>/dev/null)
    assert_eq "$1" "$e" "$a"
}
# Run ra_route in a fresh shell with CGI env; output = JSON body + @@STATUS:NNN
# marker (ra_route emits the marker itself, last line).
run_route() {  # run_route <method> <path> <query_string> <stdin_body>
    printf '%s' "$4" | sh -c '
        REQUEST_METHOD="$1" PATH_INFO="$2" QUERY_STRING="$3"
        . "$0"
        ra_route
    ' "$RA_LIB" "$1" "$2" "$3"
}
route_body()   { echo "$1" | sed '/@@STATUS:/d'; }
route_status() { echo "$1" | sed -n 's/.*@@STATUS:\([0-9]*\).*/\1/p'; }
summary() {
    echo "PASS=$PASS FAIL=$FAIL"
    [ "$FAIL" -eq 0 ]
}
