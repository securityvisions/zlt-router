#!/bin/sh
# Force the X28 onto the preferred operator (MCI) at boot, then fix DNS.
# Waits for the modem to be ready before selecting. Safe to run repeatedly.
set -eu

TARGET_PLMN="${X28_TARGET_PLMN:-43211}"   # MCI
TARGET_ACT="${X28_TARGET_ACT:-13}"

# Wait for modem to register (up to ~60s)
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    OP=$(curl -s -m 3 -H 'Content-Type: application/json' -d '{"cmd":401,"method":"GET"}' http://192.168.70.1/cgi-bin/http.cgi 2>/dev/null | sed -n 's/.*"network_operator":"\([^"]*\)".*/\1/p' | head -1)
    [ -n "$OP" ] && break
    sleep 5
done

# Read current PLMN from linkstate
CUR=$(sh /data/proxy/linkstate.sh 2>/dev/null | grep '^plmn=' | cut -d= -f2)
echo "operator-fix: current PLMN=$CUR target=$TARGET_PLMN"

# If not on target, reselect
if [ "$CUR" != "$TARGET_PLMN" ]; then
    echo "operator-fix: selecting ${TARGET_PLMN}..."
    X28_TARGET_PLMN=$TARGET_PLMN X28_TARGET_ACT=$TARGET_ACT timeout 90 sh /data/proxy/reselect.sh 2>&1 | head -1
    # wait for re-registration
    sleep 25
fi

# Re-apply clean DNS (lost on network/operator changes)
sh /data/proxy/dns-fix.sh 2>/dev/null || true

echo 'operator-fix done'
