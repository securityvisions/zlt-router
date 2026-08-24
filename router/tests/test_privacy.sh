#!/bin/sh
# Unit tests: privacy-lib — privacy scrub module for the Telegram surface.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
PL="$HERE/../x28/privacy-lib.sh"

PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n' "$2"; printf '  actual: [%s]\n' "$3"; fi; }
assert_contains() { if printf '%s' "$3" | grep -qF "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (missing: $2)"; fi; }
assert_not_contains() { if ! printf '%s' "$3" | grep -qF "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (should NOT contain: $2)"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP"
printf 'AA:BB:CC:DD:EE:77|parsa\nF4:28:9D:60:61:CB|maman\n' > "$TMP/owners.conf"
printf '1700000000 3a:7e:c0:54:29:d9 192.168.70.106 Nothing-Phone-2 01:00:00:00:00:00\n1700000000 c8:12:0b:32:7c:f2 192.168.70.155 Samsung 01:00:00:00:00:01\n' > "$TMP/leases"

sample='👥 دفتر - parsa: 5.0 GB · 38500 T
Device Nothing-Phone-2 (3a:7e:c0:54:29:d9) · 192.168.70.106
maman · Samsung · 1.2 GB'

# ── privacy off: passthrough ────────────────────────────────────────────────
out=$(PRIVACY_CONF="$TMP/conf" HN_OWNERS_FILE="$TMP/owners.conf" HN_LEASES="$TMP/leases" sh -c '. "$1"; privacy_scrub "$2"' sh "$PL" "$sample")
assert_contains "off: MAC passthrough" "3a:7e:c0:54:29:d9" "$out"
assert_contains "off: name passthrough" "parsa" "$out"
assert_contains "off: hostname passthrough" "Nothing-Phone-2" "$out"

# ── privacy on: all masked ───────────────────────────────────────────────────
printf 'PRIVACY=1\n' > "$TMP/conf"
out=$(PRIVACY_CONF="$TMP/conf" HN_OWNERS_FILE="$TMP/owners.conf" HN_LEASES="$TMP/leases" sh -c '. "$1"; privacy_scrub "$2"' sh "$PL" "$sample")
assert_not_contains "on: MAC masked" "3a:7e:c0:54:29:d9" "$out"
assert_not_contains "on: name masked" "parsa" "$out"
assert_not_contains "on: hostname masked" "Nothing-Phone-2" "$out"
assert_not_contains "on: IP masked" "192.168.70.106" "$out"
assert_contains "on: still readable structure" "5.0 GB" "$out"

# ── toggle flips state file ─────────────────────────────────────────────────
out=$(PRIVACY_CONF="$TMP/conf2" HN_OWNERS_FILE="$TMP/owners.conf" HN_LEASES="$TMP/leases" sh -c '. "$1"; privacy_toggle; privacy_state' sh "$PL")
assert_eq "toggle default -> on" "on" "$out"
out=$(PRIVACY_CONF="$TMP/conf2" HN_OWNERS_FILE="$TMP/owners.conf" HN_LEASES="$TMP/leases" sh -c '. "$1"; privacy_toggle; privacy_state' sh "$PL")
assert_eq "toggle again -> off" "off" "$out"

summary