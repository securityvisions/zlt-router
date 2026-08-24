#!/bin/sh
# Unit tests: ledger-backup — weekly Telegram archive of the Ledger history.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
LB="$HERE/../x28/ledger-backup.sh"

PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (expect [$2] got [$3])"; fi; }
assert_contains() { if printf '%s' "$3" | grep -qF "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (missing: $2)"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/owners-d" "$TMP/rollups"
printf 'parsa|3a:7e:c0:54:29:d9|1073741824|0\n' > "$TMP/owners-d/2026-08-22"
printf '2026-08-22|parsa|1073741824|7700\n' > "$TMP/rollups/1405-05.tsv"
printf 'RATE_FULL=7700\nRATE_FRIDAY=4620\n' > "$TMP/billing.conf"

export USAGE_DIR="$TMP"

# ── build: archive contains history + rollups + rates ───────────────────────
arc=$(sh "$LB" build)
[ -f "$arc" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - archive not created"; }
out=$(tar -tzf "$arc" 2>/dev/null)
assert_contains "archive has owners-d" "owners-d/2026-08-22" "$out"
assert_contains "archive has rollups" "rollups/1405-05.tsv" "$out"
assert_contains "archive has billing.conf" "billing.conf" "$out"

# ── dry-run: describes, no marker, no send ──────────────────────────────────
out=$(SEND_CMD='printf "%s" "$1" >> "'"$TMP"'/sent.log"' sh "$LB" dry-run)
assert_contains "dry-run says dry-run" "dry-run" "$out"
[ ! -f "$TMP/sent.log" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - dry-run must not send"; }
[ ! -f "$TMP/.ledger-backup-week" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - dry-run must not set marker"; }

# ── run: sends once, sets marker ────────────────────────────────────────────
: > "$TMP/sent.log"
WEEK=2026-W34 SEND_CMD='printf "%s\n" "$1" >> "'"$TMP"'/sent.log"' sh "$LB" run
assert_eq "marker set to week" "2026-W34" "$(cat "$TMP/.ledger-backup-week" 2>/dev/null)"
assert_eq "sent once" "1" "$(grep -c tar.gz "$TMP/sent.log" 2>/dev/null | tr -d ' ')"

# ── same week: marker blocks re-send ────────────────────────────────────────
WEEK=2026-W34 SEND_CMD='printf "%s\n" "$1" >> "'"$TMP"'/sent.log"' sh "$LB" run
assert_eq "no second send in same week" "1" "$(grep -c tar.gz "$TMP/sent.log" 2>/dev/null | tr -d ' ')"

# ── new week: sends again ────────────────────────────────────────────────────
WEEK=2026-W35 SEND_CMD='printf "%s\n" "$1" >> "'"$TMP"'/sent.log"' sh "$LB" run
assert_eq "new week sends again" "2" "$(grep -c tar.gz "$TMP/sent.log" 2>/dev/null | tr -d ' ')"

summary
