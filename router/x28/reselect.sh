#!/bin/sh
# reselect.sh — force the ZLT X28 back onto the preferred operator.
#
# Canonical copy lives in this repo (router/x28/reselect.sh); it deploys to the
# X28 as /data/proxy/reselect.sh. Uses the vendor SCCAN_PLMN select (cmd 228,
# plmn_select_cmd 4) which is the same call the vendor web UI makes. The select
# can take tens of seconds — callers run it with nohup/background.
#
# Env: X28_TARGET_PLMN (default 43211 = MCI), X28_TARGET_ACT (default 13).

X28_TARGET_PLMN="${X28_TARGET_PLMN:-43211}"
X28_TARGET_ACT="${X28_TARGET_ACT:-13}"
X28_BASE="${X28_BASE:-http://192.168.70.1/cgi-bin/http.cgi}"
X28_USER="${X28_USER:-admin}"
X28_PASS="${X28_PASS:-admin}"

# sha256_hex <string> — portable sha256 (sha256sum, fallback openssl dgst).
sha256_hex() {
    printf '%s' "$1" | sha256sum 2>/dev/null | awk '{print $1; exit}' |
        grep -qE '^[0-9a-f]{64}$' && {
            printf '%s' "$1" | sha256sum | awk '{print $1}'; return
        }
    printf '%s' "$1" | openssl dgst -sha256 2>/dev/null | sed 's/.*= *//'
}

token=$(curl -s -m 8 -H 'Content-Type: application/json' \
    -d '{"cmd":232,"method":"GET","sessionId":""}' "$X28_BASE" 2>/dev/null |
    sed -n 's/.*"token":"\([0-9a-f]*\)".*/\1/p' | head -1)
[ -n "$token" ] || { echo "reselect: no token" >&2; exit 1; }
pass=$(sha256_hex "${token}${X28_PASS}")
sid=$(curl -s -m 8 -H 'Content-Type: application/json' \
    -d "{\"cmd\":100,\"method\":\"POST\",\"sessionId\":\"\",\"username\":\"$X28_USER\",\"passwd\":\"$pass\",\"isAutoUpgrade\":\"0\",\"subcmd\":0,\"language\":\"en\"}" \
    "$X28_BASE" 2>/dev/null |
    sed -n 's/.*"sessionId":"\([0-9a-f]*\)".*/\1/p' | head -1)
[ -n "$sid" ] || { echo "reselect: no session" >&2; exit 1; }

resp=$(curl -s -m 90 -H 'Content-Type: application/json' \
    -d "{\"cmd\":228,\"plmn_select_cmd\":\"4\",\"plmn\":\"$X28_TARGET_PLMN\",\"act\":\"$X28_TARGET_ACT\",\"method\":\"POST\",\"sessionId\":\"$sid\",\"language\":\"en\"}" \
    "$X28_BASE" 2>/dev/null)
echo "reselect: $resp"
