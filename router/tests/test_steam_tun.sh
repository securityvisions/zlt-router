#!/bin/sh
# Fixture tests: steam-tun — route Valve/Steam CIDRs through the engine's tun.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
EN="$HERE/../x28/steam-tun-enable.sh"
DIS="$HERE/../x28/steam-tun-disable.sh"

PASS=0; FAIL=0
assert_contains() { if grep -qF -- "$2" "$3"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (missing: $2)"; fi; }
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n  actual: [%s]\n' "$2" "$3"; fi; }
count_of() { grep -oF -- "$1" "$2" 2>/dev/null | wc -l | tr -d ' '; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

STUB="$TMP/bin"; mkdir -p "$STUB"
# Fake ip: TUN_STATE holds a countdown of "device missing" probes — each
# `link show` decrements it; at zero the device reports present. Unset =
# always present (legacy behavior for the original cases below).
cat > "$STUB/ip" <<'EOF'
#!/bin/sh
echo "ip $*" >> "$RECORD"
case "$1" in
    link)
        n=$(cat "$TUN_STATE" 2>/dev/null || echo 0)
        if [ "${n:-0}" -gt 0 ]; then
            echo $((n-1)) > "$TUN_STATE"
            exit 1
        fi
        exit 0 ;;
    route)
        case "$2" in
            show)
                # replay recorded adds for the requested table only, minus
                # any CIDR the test hides via FAKE_MISSING
                tbl="${4:-main}"
                sed -n "s/^ip route add \(.*\) table $tbl\$/\1/p" "$RECORD" 2>/dev/null \
                    | grep -vF "${FAKE_MISSING:-__none__}"
                exit 0 ;;
            *) exit 0 ;;
        esac ;;
esac
exit 0
EOF
chmod +x "$STUB/ip"

export RECORD="$TMP/enable.log"
IP_BIN="$STUB/ip" sh "$EN" >/dev/null 2>&1

# ── enable routes each Valve CIDR through utun in BOTH routing tables ────────
for cidr in "162.254.192.0/18" "155.133.128.0/17" "146.66.152.0/21" "208.64.200.0/22" "185.25.182.0/23"; do
    assert_contains "valve $cidr main"  "ip route add $cidr dev utun table main"  "$RECORD"
    assert_contains "valve $cidr 17000" "ip route add $cidr dev utun table 17000" "$RECORD"
done

# ── idempotent: second enable adds no new routes ────────────────────────────
IP_BIN="$STUB/ip" sh "$EN" >/dev/null 2>&1
[ "$(count_of "ip route add" "$RECORD")" = "10" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - enable not idempotent ($(count_of "ip route add" "$RECORD") adds)"; }

# ── disable removes exactly those routes from both tables ────────────────────
export RECORD="$TMP/disable.log"
IP_BIN="$STUB/ip" sh "$DIS" >/dev/null 2>&1
[ "$(count_of "ip route del" "$RECORD")" = "10" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - disable did not remove all routes ($(count_of "ip route del" "$RECORD"))"; }
assert_contains "del in vendor table" "ip route del 162.254.192.0/18 dev utun table 17000" "$RECORD"

# ── boot race: device appears late → wait, then add ─────────────────────────
export RECORD="$TMP/delayed.log" TUN_STATE="$TMP/tun_state" STEAM_TUN_WAIT=10
echo 3 > "$TUN_STATE"
IP_BIN="$STUB/ip" sh "$EN" >/dev/null 2>&1; rc=$?
assert_eq "delayed device: exit 0"        "0" "$rc"
assert_eq "delayed device: routes added"  "10"    "$(count_of "ip route add" "$RECORD")"
probes=$(count_of "ip link show" "$RECORD")
[ "$probes" -ge 3 ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - expected ≥3 link probes before success, got $probes"; }

# ── boot race: device never appears → fail LOUDLY, add nothing ──────────────
export RECORD="$TMP/never.log" TUN_STATE="$TMP/tun_never" STEAM_TUN_WAIT=1
echo 9999 > "$TUN_STATE"
IP_BIN="$STUB/ip" sh "$EN" >/dev/null 2>&1; rc=$?
assert_eq "never appears: nonzero exit"   "1" "$rc"
assert_eq "never appears: no adds"        "0" "$(count_of "ip route add" "$RECORD")"
IP_BIN="$STUB/ip" sh "$EN" 2>&1 >/dev/null | grep -qi "did not appear" \
  && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - no operator-facing error message on stderr"; }

# ── partial add: a CIDR missing after add must fail loudly ───────────────────
export RECORD="$TMP/partial.log" TUN_STATE="$TMP/tun_ok"
echo 0 > "$TUN_STATE"
FAKE_MISSING="146.66.152.0/21" IP_BIN="$STUB/ip" sh "$EN" >/dev/null 2>&1; rc=$?
assert_eq "partial add: nonzero exit"     "1" "$rc"

# ── --persist installs the boot hook exactly once (RC_FILE seam) ─────────────
printf '# boot\nexit 0\n' > "$TMP/rc.local"
RC_FILE="$TMP/rc.local" IP_BIN="$STUB/ip" TUN_STATE="$TMP/tun_ok" sh "$EN" --persist >/dev/null 2>&1
assert_contains "persist: hook installed" "/data/proxy/steam-tun-enable.sh" "$TMP/rc.local"
RC_FILE="$TMP/rc.local" IP_BIN="$STUB/ip" TUN_STATE="$TMP/tun_ok" sh "$EN" --persist >/dev/null 2>&1
[ "$(count_of "steam-tun-enable" "$TMP/rc.local")" = "1" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - persist not idempotent"; }

# ── drift guard: the Valve CIDR set must match across all three sources ──────
cidrs_of() {
    if [ "$1" = "yaml" ]; then
        sed -n 's/^  - IP-CIDR,\([0-9./]*\)$/\1/p' "$HERE/../x28/steam-voice.yaml" | sort
    else
        # only the STEAM_CIDRS assignment — comments mention other addresses
        sed -n 's/^STEAM_CIDRS="\(.*\)"/\1/p' \
            "$HERE/../x28/steam-tun-$1.sh" | grep -oE '[0-9./]+' | sort -u
    fi
}
a=$(cidrs_of enable); b=$(cidrs_of disable); c=$(cidrs_of yaml)
if [ "$a" = "$b" ] && [ "$a" = "$c" ] && [ -n "$a" ]; then
    PASS=$((PASS+1))
else
    FAIL=$((FAIL+1)); echo "FAIL - Valve CIDR set drifted between enable/disable/steam-voice.yaml:"
    printf '  enable:  %s\n  disable: %s\n  yaml:    %s\n' "$a" "$b" "$c"
fi

# ── keeper: loop + init exist and wire the enable script continuously ────────
LOOP="$HERE/../x28/steam-tun-loop.sh"
INIT="$HERE/../x28/x28-steam-routes.init"
[ -f "$LOOP" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - keeper loop script missing"; }
grep -qF "steam-tun-enable.sh" "$LOOP" 2>/dev/null && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - loop does not invoke enable script"; }
grep -qF "STEAM_TUN_KEEPALIVE" "$LOOP" 2>/dev/null && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - loop lacks interval seam"; }
[ -f "$INIT" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - keeper init missing"; }
grep -qF "steam-tun-loop.sh" "$INIT" 2>/dev/null && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - init does not run the loop"; }

summary