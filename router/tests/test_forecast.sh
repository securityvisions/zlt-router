#!/bin/sh
# Unit tests: router/forecast.sh — month-end projection wiring.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
F="$HERE/../forecast.sh"

PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
ck() {  # ck <desc> <expected_pattern> <output>
    if echo "$2" | grep -q "$3"; then PASS=$((PASS+1)); else
        FAIL=$((FAIL+1)); echo "FAIL - $1: expected [$3] in [$2]"; fi
}

# Fixture month log: 5 GB total across two devices.
mkdir -p "$TMP/usage"
printf '2026-08-01|aa:bb:cc:dd:ee:01|2147483648\n' >> "$TMP/usage/$(date +%Y-%m).log"
printf '2026-08-02|aa:bb:cc:dd:ee:02|3221225472\n' >> "$TMP/usage/$(date +%Y-%m).log"
export HN_LIB="$HERE/../hnlib.sh"

out=$(USAGE_DIR="$TMP/usage" sh "$F" --report 2>&1)
ck "report header" "$out" "Month-end forecast"
ck "report shows used" "$out" "Used: 5.000 GB"
ck "report shows projected" "$out" "Projected:"

# Budget decision path runs without error (state injected).
out=$(USAGE_DIR="$TMP/usage" FORECAST_STATE="$TMP/s" FORECAST_COOLDOWN_S=1 sh "$F" 2>&1)
case "$out" in OK|ALERT\|budget) PASS=$((PASS+1)) ;; *) FAIL=$((FAIL+1)); echo "FAIL - main path: got [$out]" ;; esac

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
