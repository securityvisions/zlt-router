#!/bin/sh
# x28lib.sh — shared helpers for the X28 smart-edge scripts.
#
# Canonical copy lives in this repo (router/x28/x28lib.sh); it deploys
# alongside linkstate.sh and reselect.sh (same directory on each device), so
# callers source it as "${X28_LIB:-$(dirname "$0")/x28lib.sh}".

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

# x28_field <json> <key> — extract a JSON string field (values are ASCII here).
x28_field() {
    printf '%s' "$1" | sed -n "s/.*\"$2\":\"\([^\"]*\)\".*/\1/p" | head -1
}

# x28_session — bootstrap the vendor API session; sets X28_TOKEN / X28_SID.
# Returns non-zero on failure.
x28_session() {
    local resp pass
    X28_TOKEN=
    X28_SID=
    resp=$(curl -s -m 8 -H 'Content-Type: application/json' \
        -d '{"cmd":232,"method":"GET","sessionId":""}' "$X28_BASE" 2>/dev/null)
    X28_TOKEN=$(printf '%s' "$resp" | sed -n 's/.*"token":"\([0-9a-f]*\)".*/\1/p' | head -1)
    [ -n "$X28_TOKEN" ] || return 1
    pass=$(sha256_hex "${X28_TOKEN}${X28_PASS}")
    resp=$(curl -s -m 8 -H 'Content-Type: application/json' \
        -d "{\"cmd\":100,\"method\":\"POST\",\"sessionId\":\"\",\"username\":\"$X28_USER\",\"passwd\":\"$pass\",\"isAutoUpgrade\":\"0\",\"subcmd\":0,\"language\":\"en\"}" \
        "$X28_BASE" 2>/dev/null)
    X28_SID=$(printf '%s' "$resp" | sed -n 's/.*"sessionId":"\([0-9a-f]*\)".*/\1/p' | head -1)
    [ -n "$X28_SID" ]
}

# x28_api <cmd> <method> [extra-json-fields] — one raw vendor API response.
# Reads a fixture directory instead of the live API when X28_FIXTURE_DIR is
# set (tests exercise the same parsing the live router uses).
x28_api() {
    local cmd="$1" method="${2:-GET}" extra="${3:-}"
    if [ -n "$X28_FIXTURE_DIR" ]; then
        cat "$X28_FIXTURE_DIR/cmd$cmd.json" 2>/dev/null
        return 0
    fi
    x28_session || return 1
    curl -s -m 8 -H 'Content-Type: application/json' \
        -d "{\"cmd\":$cmd,\"method\":\"$method\",\"sessionId\":\"$X28_SID\",\"language\":\"en\"$extra}" \
        "$X28_BASE" 2>/dev/null
}
