#!/bin/sh
# Fixture tests: tv-p2p-enable — TV peer traffic egresses the carrier, and
# the TV's UDP (DHT/trackers) rides the engine tun.
#
# Measured 2026-08-26: BitTorrent peers refuse the VPS datacenter IP
# (18/18 handshakes dropped via tunnel; handshake+data via carrier), and
# the carrier selectively drops international UDP. The TV therefore gets:
#   TCP (non-web ports) -> carrier-direct; web 80/443 -> tunnel
#   UDP -> marked and policy-routed into the engine tun, LAN/multicast exempt
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
EN="$HERE/../x28/tv-p2p-enable.sh"

PASS=0; FAIL=0
assert_contains() { if grep -qF -- "$2" "$3" 2>/dev/null; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (missing: $2)"; fi; }
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n  actual: [%s]\n' "$2" "$3"; fi; }
count_of() { grep -oF -- "$1" "$2" 2>/dev/null | wc -l | tr -d ' '; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin"
export RECORD="$TMP/enable.log" RECORD2="$TMP/ip.log"
export IPT_BIN="$TMP/bin/iptables" IP_BIN="$TMP/bin/ip" TV_IP="192.168.70.155"

cat > "$TMP/bin/iptables" <<'EOF'
#!/bin/sh
case " $* " in
    *" -C "*)
        # rule tail = everything after "-C <chain>"; log inserts only, so the
        # probe can never match its own probe line
        while [ $# -gt 0 ] && [ "$1" != "-C" ]; do shift; done
        shift; shift
        grep -qF -- "$*" "$RECORD" 2>/dev/null && exit 0 || exit 1 ;;
    *" -D "*) exit 0 ;;
    *) echo "iptables $*" >> "$RECORD" ;;
esac
exit 0
EOF

cat > "$TMP/bin/ip" <<'EOF'
#!/bin/sh
echo "ip $*" >> "$RECORD2"
case " $* " in
    *" rule show "*|*" rule"*) sed -n 's/^ip rule add //p' "$RECORD2" 2>/dev/null | sort -u; exit 0 ;;
    *" route show table "*)
        tbl=$(printf '%s' "$*" | sed 's/.*table //')
        sed -n "s/^ip route add \(.*table $tbl\)\$/\1/p" "$RECORD2" 2>/dev/null | sort -u
        exit 0 ;;
    *) exit 0 ;;
esac
EOF
chmod +x "$TMP/bin/iptables" "$TMP/bin/ip"

# ── run 1: everything inserts; exits clean ───────────────────────────────────
sh "$EN" >/dev/null 2>&1; rc=$?
assert_eq "enable exits 0" "0" "$rc"

# ── TCP: P2P bypass, scoped to the TV, web ports excluded ────────────────────
assert_contains "TV source pinned"       "-s 192.168.70.155" "$RECORD"
assert_contains "web ports excluded"     "! --dports 80,443" "$RECORD"
assert_contains "returns from intercept" "-j RETURN"         "$RECORD"
assert_contains "in the intercept chain" "-I X28_SPLIT"      "$RECORD"

# ── UDP: mark + fwmark rule + tun default table ──────────────────────────────
assert_eq "mangle rules inserted once each" "3" "$(count_of 'iptables -t mangle -I PREROUTING' "$RECORD")"
assert_contains "mark excludes LAN dst"     "192.168.0.0/16"    "$RECORD"
assert_contains "mark excludes multicast"   "224.0.0.0/4"       "$RECORD"
assert_contains "mark targets the TV"       "192.168.70.155"    "$RECORD"
assert_eq "fwmark policy rule added"        "1" "$(grep -c 'ip rule add fwmark' "$RECORD2")"
assert_eq "default route via tun in table"  "1" "$(grep -c 'ip route add default dev utun table' "$RECORD2")"

# ── idempotent: second run adds nothing anywhere ─────────────────────────────
sh "$EN" >/dev/null 2>&1; rc=$?
assert_eq "second run exits 0" "0" "$rc"
assert_eq "nat insert idempotent"     "1" "$(count_of 'iptables -t nat -I X28_SPLIT' "$RECORD")"
assert_eq "mangle inserts idempotent" "3" "$(count_of 'iptables -t mangle -I PREROUTING' "$RECORD")"
assert_eq "fwmark rules idempotent"   "1" "$(grep -c 'ip rule add fwmark' "$RECORD2")"

# ── enable wired into the keeper loop ────────────────────────────────────────
grep -qF "tv-p2p-enable.sh" "$HERE/../x28/steam-tun-loop.sh" \
  && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - keeper loop does not assert the TV P2P rule"; }

summary
