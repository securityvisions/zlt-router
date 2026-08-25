#!/bin/sh
# Fixture tests: dashboard snapshot generator's Ledger slice.
# Contract: ledger.json holds real per-person rows when the single Ledger
# store resolves through the unified chain (env > beside script > canonical
# device paths); a loud {"error":…} object — which the card renders red —
# when it cannot, never a quiet empty array.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
DD="$HERE/../x28/x28-dash-data.sh"
STORE="$HERE/../x28/ledger-store.sh"

PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n' "$2"; printf '  actual: [%s]\n' "$3"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/owners-d" "$TMP/out" "$TMP/bin"
cat > "$TMP/owners-d/2026-07-23" <<'EOF'
Ali|aa:bb:cc:dd:ee:ff|1073741824|0
Sara|11:22:33:44:55:66|0|2147483648
EOF
cat > "$TMP/owners-d/2026-07-24" <<'EOF'
Ali|aa:bb:cc:dd:ee:ff|536870912|0
unassigned|de:ad:be:ef:00:01|1073741824|100
EOF
printf 'RATE_FULL=7700\nRATE_FRIDAY=4620\n' > "$TMP/billing.conf"

export USAGE_DIR="$TMP" HN_LIB="$HERE/../hnlib.sh" JQ_BIN="$(command -v jq)"
export DASH_DIR="$TMP/out" DASH_TODAY="2026-07-24" PEOPLE_TODAY="2026-07-24"

jget() { jq -r "$2" "$DASH_DIR/ledger.json" 2>/dev/null; }

# ── 1. env-seam resolution: rows land in ledger.json ────────────────────────
# NB: fixture copy keeps the canonical basename — the store gates its CLI on it
mkdir -p "$TMP/store"
cp "$STORE" "$TMP/store/ledger-store.sh"
LEDGER_STORE="$TMP/store/ledger-store.sh" sh "$DD" once
assert_eq "rows count"            "3"           "$(jget x 'length')"
assert_eq "Sara row first (top)"  "Sara"        "$(jget x '.[0].person')"
assert_eq "Ali bytes"             "1610612736"  "$(jget x '.[]|select(.person=="Ali")|.bytes')"
assert_eq "Sara bytes"            "2147483648"  "$(jget x '.[]|select(.person=="Sara")|.bytes')"
assert_eq "unassigned bytes"      "1073741924"  "$(jget x '.[]|select(.person=="unassigned")|.bytes')"
assert_eq "no error object (payload is an array)" "array" "$(jget x 'type')"
[ "$(jget x '.[0].cost_toman')" -gt 0 ] 2>/dev/null && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - Sara cost_toman not positive"; }

# ── 2. chain falls through to a store beside the script (env unset) ─────────
rm -f "$DASH_DIR"/ledger.json
cp "$DD" "$TMP/bin/dash-data.sh"   # relocated copy: its dirname is the sandbox
cp "$STORE" "$TMP/bin/ledger-store.sh"
sh "$TMP/bin/dash-data.sh" once
assert_eq "sibling: rows found"   "3"     "$(jget x 'length')"
assert_eq "sibling: top person"   "Sara"  "$(jget x '.[0].person')"

# ── 3. nothing resolvable → loud error object, valid JSON ───────────────────
rm -f "$DASH_DIR"/ledger.json "$TMP/bin/ledger-store.sh"
sh "$TMP/bin/dash-data.sh" once
assert_eq "error emitted" "ledger store unavailable" "$(jget x '.error')"

# ── 4. unusable date → loud error, not silent [] ─────────────────────────────
rm -f "$DASH_DIR"/ledger.json
DASH_TODAY="not-a-date" sh "$DD" once
assert_eq "bad date errors loudly" "jalali date unavailable" "$(jget x '.error')"

summary
