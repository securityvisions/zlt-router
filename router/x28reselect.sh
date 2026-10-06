#!/bin/sh
# x28reselect.sh — Safe operator re-selection adapter for AX3000T -> X28.
#
# Primary path: calls modem-supervisor.sh on X28 via SSH (enforces 600s
# cooldown, max 3/hr storm guard, and direct AT command reselection).
# Fallback path: calls vendor HTTP API cmd 228 via x28lib.sh.
#
# Env:
#   X28_TARGET_PLMN (default: 43211)
#   X28_TARGET_ACT  (default: 13)
#   X28_IP          (default: 192.168.70.1)

set -u

X28_TARGET_PLMN="${X28_TARGET_PLMN:-43211}"
X28_TARGET_ACT="${X28_TARGET_ACT:-13}"
X28_IP="${X28_IP:-192.168.70.1}"
X28_PASS="${X28_PASS:-G5K0utrzATYX}"
HERE="$(dirname "$0")"

# 1. Try X28 modem supervisor over SSH
if command -v sshpass >/dev/null 2>&1; then
    resp=$(sshpass -p "$X28_PASS" ssh -o StrictHostKeyChecking=no -o HostKeyAlgorithms=+ssh-rsa -o ConnectTimeout=5 \
        "root@$X28_IP" "/data/proxy/modem-supervisor.sh switch '$X28_TARGET_PLMN' '$X28_TARGET_ACT'" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$resp" ]; then
        echo "x28reselect (ssh): $resp"
        exit 0
    fi
fi

# 2. Fallback: vendor HTTP API (cmd 228)
LIB="${X28_LIB:-$HERE/x28lib.sh}"
if [ -f "$LIB" ]; then
    . "$LIB"
    if x28_session; then
        resp=$(curl -s -m 90 -H 'Content-Type: application/json' \
            -d "{\"cmd\":228,\"plmn_select_cmd\":\"4\",\"plmn\":\"$X28_TARGET_PLMN\",\"act\":\"$X28_TARGET_ACT\",\"method\":\"POST\",\"sessionId\":\"$X28_SID\",\"language\":\"en\"}" \
            "$X28_BASE" 2>/dev/null)
        echo "x28reselect (http): $resp"
        exit 0
    fi
fi

echo "x28reselect: failed to reach X28 modem controller" >&2
exit 1
