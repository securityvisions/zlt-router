#!/bin/sh
# Fixture tests: tv-p2p-enable — TV peer traffic egresses the carrier.
#
# Peers accept the carrier IP and refuse the VPS datacenter IP (measured
# 2026-08-26: 18/18 handshakes dropped via tunnel; handshake+data via
# carrier). The TV's P2P TCP (all ports except web 80/443) must RETURN
# from the intercept chain so it exits direct, while its web traffic
# (Netflix, Stremio UI) keeps riding the tunnel.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
EN="$HERE/../x28/tv-p2p-enable.sh"

PASS=0; FAIL=0
assert_contains() { if grep -qF -- "$2" "$3" 2>/dev/null; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (missing: $2)"; fi; }
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n  actual: [%s]\n' "$2" "$3"; fi; }
count_of() { grep -oF -- "$1" "$2" 2>/dev/null | wc -l | tr -d ' '; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin"
cat > "$TMP/bin/iptables" <<'EOF'
#!/bin/sh
echo "iptables $*" >> "$RECORD"
case " $* " in
    *" -C "*)
        # rule args = everything after the chain name; inserts always carry position 1
        while [ "$1" != "X28_SPLIT" ] && [ $# -gt 0 ]; do shift; done; shift
        grep -qF -- "iptables -t nat -I X28_SPLIT 1 $*" "$RECORD" 2>/dev/null && exit 0 || exit 1 ;;
    *" -D "*) exit 0 ;;
esac
exit 0
EOF
chmod +x "$TMP/bin/iptables"

export RECORD="$TMP/enable.log" IPT_BIN="$TMP/bin/iptables" TV_IP="192.168.70.155"
sh "$EN" >/dev/null 2>&1; rc=$?

# ── correct rule, at the right scope ─────────────────────────────────────────
assert_eq "enable exits 0" "0" "$rc"
assert_contains "TV source pinned"        "-s 192.168.70.155"              "$RECORD"
assert_contains "web ports excluded"      "! --dports 80,443"              "$RECORD"
assert_contains "returns from intercept"  "-j RETURN"                      "$RECORD"
assert_contains "in the intercept chain"  "-I X28_SPLIT"                   "$RECORD"

# ── idempotent: second run adds nothing ──────────────────────────────────────
sh "$EN" >/dev/null 2>&1
assert_eq "idempotent (one insert)" "1" "$(count_of "iptables -t nat -I X28_SPLIT" "$RECORD")"

# ── enable also wired into the keeper loop ───────────────────────────────────
grep -qF "tv-p2p-enable.sh" "$HERE/../x28/steam-tun-loop.sh" \
  && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - keeper loop does not assert the TV P2P rule"; }

summary
