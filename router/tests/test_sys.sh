#!/bin/sh
# Unit tests: hn_sys_* system-state readers in hnlib.sh — the deep module behind
# /status, the bot dashboard, the hourly snapshot and the disk/reboot alerts.
# One implementation of "what is the router doing right now" shared by four callers.
#
# Tested at the module seam like hn_balance_fields: the file-backed readers
# (load, temp) are exercised with real fixture files; the command-backed readers
# (mem/disk/uptime/proxy/nlbw) and the snapshot composer are exercised by
# overriding the per-metric functions — the same fixture-override trick the
# Router API tests use for ra_*.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
HN_LIB="$HERE/../hnlib.sh"
[ -f "$HN_LIB" ] || HN_LIB="$HERE/hnlib.sh"
. "$HN_LIB"

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

# ── hn_sys_load — parse the 1-min load average from a file ────────────────────
echo "0.10 0.05 0.02 1/123 4567" > "$TMP/loadavg"
assert_eq "load: field 1" "0.10" "$(hn_sys_load "$TMP/loadavg")"
echo "2.50 2.30 2.10 4/456 7890" > "$TMP/loadavg2"
assert_eq "load: higher" "2.50" "$(hn_sys_load "$TMP/loadavg2")"
assert_eq "load: missing file -> empty" "" "$(hn_sys_load "$TMP/nonexistent")"

# ── hn_sys_temp_c — parse thermal millidegrees to °C ─────────────────────────
echo "48000" > "$TMP/thermal"
assert_eq "temp: 48C" "48" "$(hn_sys_temp_c "$TMP/thermal")"
echo "76350" > "$TMP/thermal2"
assert_eq "temp: 76C" "76" "$(hn_sys_temp_c "$TMP/thermal2")"
assert_eq "temp: missing file -> empty" "" "$(hn_sys_temp_c "$TMP/nonexistent")"

# ── hn_sys_snapshot — compose all seven metrics into key=value lines ─────────
# Override the command-backed readers with fixtures; the file-backed ones
# (load/temp) point at real fixture files via HN_SYS_LOADAVG/HN_SYS_THERMAL.
HN_SYS_LOADAVG="$TMP/loadavg"
HN_SYS_THERMAL="$TMP/thermal"
hn_sys_mem()       { echo "412 944"; }
hn_sys_disk()      { echo "68|3.1G"; }
hn_sys_uptime()    { echo "3 days, 4:12"; }
hn_sys_proxy_state() { echo "up|0.31"; }
hn_sys_nlbw_total()  { echo "1234567890"; }

out=$(hn_sys_snapshot)
assert_eq "snapshot: load"       "0.10" "$(echo "$out" | sed -n 's/^load=//p')"
assert_eq "snapshot: mem"        "412 944" "$(echo "$out" | sed -n 's/^mem=//p')"
assert_eq "snapshot: temp_c"     "48" "$(echo "$out" | sed -n 's/^temp_c=//p')"
assert_eq "snapshot: disk"       "68|3.1G" "$(echo "$out" | sed -n 's/^disk=//p')"
assert_eq "snapshot: uptime"     "3 days, 4:12" "$(echo "$out" | sed -n 's/^uptime=//p')"
assert_eq "snapshot: proxy"      "up|0.31" "$(echo "$out" | sed -n 's/^proxy=//p')"
assert_eq "snapshot: nlbw_total" "1234567890" "$(echo "$out" | sed -n 's/^nlbw_total=//p')"

# ── proxy state: 204 => up, non-204 => down (curl mocked as a function) ──────
# The snapshot section above overrode hn_sys_proxy_state; re-source hnlib to
# restore the real body before testing it with a mocked curl.
. "$HN_LIB"
HN_SYS_PROXY_URL="https://www.gstatic.com/generate_204"
curl() { printf '%s' "204|0.31"; }
assert_eq "proxy: 204 -> up" "up|0.31" "$(hn_sys_proxy_state)"
curl() { printf '%s' "403|"; }
assert_eq "proxy: 403 -> down" "down|" "$(hn_sys_proxy_state)"
unset -f curl 2>/dev/null || true

# ── hn_sys_nlbw_* — per-device rows and total sum from the nlbw fixture ──────
cat > "$TMP/nlbw.json" <<'EOF'
{"data": [
  ["aa:bb:cc:dd:ee:ff", 1, 2147483648, 0, 1073741824],
  ["96:04:e1:00:00:00", 2, 4294967296, 0, 1073741824]
]}
EOF
cat > "$TMP/nlbw.sh" <<EOF
#!/bin/sh
cat "$TMP/nlbw.json"
EOF
chmod +x "$TMP/nlbw.sh"
export HN_SYS_NLBW="$TMP/nlbw.sh"
assert_eq "nlbw macs: per-device rows" "aa:bb:cc:dd:ee:ff|2147483648|1073741824
96:04:e1:00:00:00|4294967296|1073741824" "$(hn_sys_nlbw_macs)"
assert_eq "nlbw total: rx+tx sum" "8589934592" "$(hn_sys_nlbw_total)"
unset HN_SYS_NLBW

summary
