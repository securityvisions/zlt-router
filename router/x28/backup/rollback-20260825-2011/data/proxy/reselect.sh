#!/bin/sh
# reselect.sh — force the ZLT X28 back onto the preferred operator.
#
# Canonical copy lives in this repo (router/x28/reselect.sh); it deploys to
# the AX3000T as /root/x28reselect.sh (beside x28lib.sh). Uses the vendor
# SCCAN_PLMN select (cmd 228, plmn_select_cmd 4) — the same call the vendor
# web UI makes. The select can take tens of seconds; callers run it with a
# generous timeout.
#
# Env: X28_TARGET_PLMN (default 43211 = MCI), X28_TARGET_ACT (default 13).

. "${X28_LIB:-$(dirname "$0")/x28lib.sh}"

X28_TARGET_PLMN="${X28_TARGET_PLMN:-43211}"
X28_TARGET_ACT="${X28_TARGET_ACT:-13}"

x28_session || { echo "reselect: no session" >&2; exit 1; }
resp=$(curl -s -m 90 -H 'Content-Type: application/json' \
    -d "{\"cmd\":228,\"plmn_select_cmd\":\"4\",\"plmn\":\"$X28_TARGET_PLMN\",\"act\":\"$X28_TARGET_ACT\",\"method\":\"POST\",\"sessionId\":\"$X28_SID\",\"language\":\"en\"}" \
    "$X28_BASE" 2>/dev/null)
echo "reselect: $resp"
