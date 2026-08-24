#!/bin/sh
# Unit tests: ledger-guard — Ledger history retention guard.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
LG="$HERE/../x28/ledger-guard.sh"

PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (expect [$2] got [$3])"; fi; }
assert_contains() { if printf '%s' "$3" | grep -qF "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (missing: $2)"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/owners-d"
for d in 2026-08-20 2026-08-21 2026-08-22 2026-08-23 2026-08-24; do
    printf 'parsa|3a:7e:c0:54:29:d9|1|1\n' > "$TMP/owners-d/$d"
done
export USAGE_DIR="$TMP"
ALERT_CMD='printf "%s\n" "$1" >> "'"$TMP"'/alerts.log"'; export ALERT_CMD

# ── first check: baseline recorded, no alert ────────────────────────────────
sh "$LG" check
[ ! -f "$TMP/alerts.log" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - baseline must not alert"; }
assert_contains "state records oldest" "2026-08-20" "$(cat "$TMP/.ledger-span" 2>/dev/null)"

# ── growth: no alert, state follows ─────────────────────────────────────────
printf 'parsa|3a:7e:c0:54:29:d9|1|1\n' > "$TMP/owners-d/2026-08-25"
sh "$LG" check
[ ! -f "$TMP/alerts.log" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - growth must not alert"; }

# ── shrinkage from the front: alert fires once ──────────────────────────────
rm -f "$TMP/owners-d/2026-08-20" "$TMP/owners-d/2026-08-21"
out=$(sh "$LG" check; cat "$TMP/alerts.log" 2>/dev/null)
assert_contains "shrinkage alerts" "history shrank" "$out"
assert_contains "alert names the moved boundary" "oldest day moved" "$out"
assert_eq "alerts exactly once" "1" "$(grep -c "history shrank" "$TMP/alerts.log" 2>/dev/null | tr -d ' ')"
# state updated to the new reality → re-check stays silent
sh "$LG" check
assert_eq "no repeat alert" "1" "$(grep -c "history shrank" "$TMP/alerts.log" 2>/dev/null | tr -d ' ')"

# ── run mode: monthly marker gates the check ────────────────────────────────
: > "$TMP/alerts.log"
MONTH=2026-08 sh "$LG" run
MONTH=2026-08 sh "$LG" run
assert_eq "run mode checks once per month" "0" "$(grep -c retention "$TMP/alerts.log" 2>/dev/null | tr -d ' ')"
assert_contains "month marker set" "2026-08" "$(cat "$TMP/.ledger-span.month" 2>/dev/null)"

summary
