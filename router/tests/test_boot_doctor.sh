#!/bin/sh
# Unit tests: Boot Doctor — pure repair planner (hn_boot_repair_plan).
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
HN_LIB="$HERE/../hnlib.sh"
[ -f "$HN_LIB" ] || HN_LIB="$HERE/hnlib.sh"
. "$HN_LIB"

PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n' "$2"; printf '  actual: [%s]\n' "$3"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }

mk_health() {  # realistic health-gate output (every check carries a detail)
    cat <<EOF
PASS dns_chain (resolved=10.11.12.13 mode=tunnel)
PASS proxied_path (HTTP 200)
PASS direct_path (HTTP 200)
PASS tproxy_chain (X28_SPLIT redirects tcp -> 12345)
PASS quic_block (X28_NOQUIC drops udp/443)
PASS xray_core (mihomo running)
PASS op_watchdog (running)
PASS v2raya
----
HEALTH: GREEN
EOF
}

# build variants by sed-replacing single check lines from a base GREEN output
base=$(mk_health)
rep() { printf '%s\n' "$base" | sed "s|^PASS $1 |FAIL $1 |"; }

# healthy boot → no repairs
assert_eq "plan: green -> none" "" "$(hn_boot_repair_plan "$base")"

# upstream-only failure → no LOCAL repair (watchdog/heal own it)
assert_eq "plan: proxied_path alone -> none" "" "$(hn_boot_repair_plan "$(rep proxied_path)")"

# iptables chains missing at boot → rules
assert_eq "plan: tproxy_chain -> rules" "rules" "$(hn_boot_repair_plan "$(rep tproxy_chain)")"
assert_eq "plan: quic_block -> rules" "rules" "$(hn_boot_repair_plan "$(rep quic_block)")"
# both chain checks fail → single 'rules' (dedup)
both=$(printf '%s\n' "$base" | sed -e 's|^PASS tproxy_chain |FAIL tproxy_chain |' -e 's|^PASS quic_block |FAIL quic_block |')
assert_eq "plan: both chains -> rules once" "rules" "$(hn_boot_repair_plan "$both")"

# DNS mode unknown / dnsmasq broken → dns
assert_eq "plan: dns_chain -> dns" "dns" "$(hn_boot_repair_plan "$(rep dns_chain)")"

# engine not running → proxy
proxy_fail=$(printf '%s\n' "$base" | sed 's|^PASS xray_core (mihomo running)|FAIL xray_core (mihomo not running)|')
assert_eq "plan: xray_core -> proxy" "proxy" "$(hn_boot_repair_plan "$proxy_fail")"

# watchdog dead → watchdog
wd_fail=$(printf '%s\n' "$base" | sed 's|^PASS op_watchdog (running)|FAIL op_watchdog (not running)|')
assert_eq "plan: op_watchdog -> watchdog" "watchdog" "$(hn_boot_repair_plan "$wd_fail")"

# multi-failure → stable order rules, dns, proxy, watchdog, deduped
MULTI="FAIL tproxy_chain
FAIL dns_chain
FAIL xray_core
FAIL op_watchdog
FAIL proxied_path
HEALTH: RED (5 check(s) failed)"
assert_eq "plan: multi order+dedup" "rules
dns
proxy
watchdog" "$(hn_boot_repair_plan "$MULTI")"

# legacy v2raya failure must NOT trigger any repair
va=$(printf '%s\n' "$base" | sed 's|^PASS v2raya|FAIL v2raya|')
assert_eq "plan: v2raya ignored" "" "$(hn_boot_repair_plan "$va")"

# empty/garbage input → nothing
assert_eq "plan: empty input" "" "$(hn_boot_repair_plan "")"
assert_eq "plan: garbage input" "" "$(hn_boot_repair_plan "random text
no fails here")"

summary
