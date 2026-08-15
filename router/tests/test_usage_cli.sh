#!/bin/sh
# Contract tests: usage.sh CLI — pins the six flags' output shapes so the ten
# call sites (botcmd.sh, billing.sh, routerapi_lib.sh) can rely on them.
# Runs the real script against fixture paths (NLBW_BIN, DHCP_LEASES, USAGE_DIR).
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
USAGE_SH="$HERE/../usage.sh"

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
summary() {
    echo "PASS=$PASS FAIL=$FAIL"
    [ "$FAIL" -eq 0 ]
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Fixture nlbw JSON (mac, id, rx, tx) — real nlbw rows carry extra fields so
# tx lives at index 4, not 3.
cat > "$TMP/nlbw.json" <<'EOF'
{"data": [
  ["96:04:e1:00:00:00", 1, 4294967296, 0, 1073741824],
  ["aa:bb:cc:dd:ee:ff", 2, 2147483648, 0, 1073741824],
  ["11:22:33:44:55:66", 3, 536870912, 0, 0]
]}
EOF
cat > "$TMP/nlbw.sh" <<EOF
#!/bin/sh
cat "$TMP/nlbw.json"
EOF
chmod +x "$TMP/nlbw.sh"

cat > "$TMP/dhcp.leases" <<'EOF'
1786776362 96:04:e1:00:00:00 192.168.1.50 laptop *
1786776362 aa:bb:cc:dd:ee:ff 192.168.1.51 iPhone *
EOF

mkdir -p "$TMP/usage-log"
# baseline snapshot: lower than current totals so diffs come out positive
echo "96:04:e1:00:00:00 4294967296" > "$TMP/usage-log/last"
# user-names lives inside USAGE_DIR (USER_NAMES derives from it)
echo "aa:bb:cc:dd:ee:ff iPhone" > "$TMP/usage-log/user-names"

export NLBW_BIN="$TMP/nlbw.sh"
export DHCP_LEASES="$TMP/dhcp.leases"
export USAGE_DIR="$TMP/usage-log"
unset USER_NAMES  # derived from USAGE_DIR by usage.sh

# --raw: cumulative rows name|mac|bytes (router macs excluded)
out=$(sh "$USAGE_SH" --raw)
assert_eq "raw: rows" "laptop|96:04:e1:00:00:00|5368709120
iPhone|aa:bb:cc:dd:ee:ff|3221225472
Unknown-11:22:33|11:22:33:44:55:66|536870912" "$out"

# --today: diff vs baseline (idempotent, drops non-positive diffs)
out=$(sh "$USAGE_SH" --today)
assert_eq "today: diff only positive" "laptop|96:04:e1:00:00:00|1073741824
iPhone|aa:bb:cc:dd:ee:ff|3221225472
Unknown-11:22:33|11:22:33:44:55:66|536870912" "$out"

# --name: user-names win, then lease, then Unknown
assert_eq "name: user name" "iPhone" "$(sh "$USAGE_SH" --name aa:bb:cc:dd:ee:ff)"
assert_eq "name: lease fallback" "laptop" "$(sh "$USAGE_SH" --name 96:04:e1:00:00:00)"
assert_eq "name: unknown" "Unknown-11:22:33" "$(sh "$USAGE_SH" --name 11:22:33:44:55:66)"

# --resolve: full mac or unique prefix -> colon form
assert_eq "resolve: full mac" "96:04:e1:00:00:00" "$(sh "$USAGE_SH" --resolve 96:04:e1:00:00:00)"
assert_eq "resolve: prefix" "aa:bb:cc:dd:ee:ff" "$(sh "$USAGE_SH" --resolve aabbcc)"
assert_eq "resolve: ambiguous -> empty" "" "$(sh "$USAGE_SH" --resolve 00:00)"

# --names: full device list mac|name|source|bytes (sorted by mac)
out=$(sh "$USAGE_SH" --names)
assert_eq "names: all known devices" "11:22:33:44:55:66|Unknown-11:22:33|unknown|536870912
96:04:e1:00:00:00|laptop|lease|5368709120
aa:bb:cc:dd:ee:ff|iPhone|user|3221225472" "$out"

# --month: sum a monthly log per mac with names resolved
cat > "$TMP/usage-log/2026-08.log" <<'EOF'
2026-08-01|aa:bb:cc:dd:ee:ff|1073741824
2026-08-02|aa:bb:cc:dd:ee:ff|1073741824
EOF
out=$(sh "$USAGE_SH" --month 2026-08)
assert_eq "month: summed per mac" "iPhone|aa:bb:cc:dd:ee:ff|2147483648" "$out"

summary
