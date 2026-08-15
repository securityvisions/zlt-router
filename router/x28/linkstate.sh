#!/bin/sh
# linkstate.sh — ZLT X28 link-state reader.
#
# Canonical copy lives in this repo (router/x28/linkstate.sh); it deploys to the
# X28 as /data/proxy/linkstate.sh. Reads the vendor JSON API and emits one
# key=value line per field:
#
#   operator   network operator name (e.g. "IR - MCI Wap", "Rightel")
#   plmn       serving PLMN (e.g. 43211) — empty when the modem scan is busy
#   tech       technology (5G(NSA) / 4G / ...)
#   signal     vendor signal level (0-5, UI scale)
#   rsrp       LTE anchor RSRP in dBm (empty when not reported)
#   rsrp_5g    5G NR RSRP in dBm (empty when not on NSA)
#   flow_dl    session download MB
#   flow_ul    session upload MB
#
# Design: the raw vendor responses are read through x28_api(), which curls the
# live API unless X28_FIXTURE_DIR points at a directory holding cmd401.json /
# cmd113.json (and optionally cmd270.json) fixture files — so tests exercise the
# exact same parsing the live router uses.

X28_BASE="${X28_BASE:-http://192.168.70.1/cgi-bin/http.cgi}"
X28_USER="${X28_USER:-admin}"
X28_PASS="${X28_PASS:-admin}"
X28_FIXTURE_DIR="${X28_FIXTURE_DIR:-}"

# sha256_hex <string> — portable sha256 (sha256sum, fallback openssl dgst).
sha256_hex() {
    printf '%s' "$1" | sha256sum 2>/dev/null | awk '{print $1; exit}' |
        grep -qE '^[0-9a-f]{64}$' && {
            printf '%s' "$1" | sha256sum | awk '{print $1}'; return
        }
    printf '%s' "$1" | openssl dgst -sha256 2>/dev/null | sed 's/.*= *//'
}

# x28_api <cmd> <method> [extra-json-fields] — one raw vendor API response.
x28_api() {
    local cmd="$1" method="${2:-GET}" extra="${3:-}"
    if [ -n "$X28_FIXTURE_DIR" ]; then
        cat "$X28_FIXTURE_DIR/cmd$cmd.json" 2>/dev/null
        return 0
    fi
    # Live path: session bootstrap (token -> login -> session id).
    local token pass sid
    token=$(curl -s -m 8 -H 'Content-Type: application/json' \
        -d "{\"cmd\":232,\"method\":\"GET\",\"sessionId\":\"\"}" "$X28_BASE" 2>/dev/null |
        sed -n 's/.*"token":"\([0-9a-f]*\)".*/\1/p' | head -1)
    [ -n "$token" ] || return 1
    pass=$(sha256_hex "${token}${X28_PASS}")
    sid=$(curl -s -m 8 -H 'Content-Type: application/json' \
        -d "{\"cmd\":100,\"method\":\"POST\",\"sessionId\":\"\",\"username\":\"$X28_USER\",\"passwd\":\"$pass\",\"isAutoUpgrade\":\"0\",\"subcmd\":0,\"language\":\"en\"}" \
        "$X28_BASE" 2>/dev/null |
        sed -n 's/.*"sessionId":"\([0-9a-f]*\)".*/\1/p' | head -1)
    [ -n "$sid" ] || return 1
    curl -s -m 8 -H 'Content-Type: application/json' \
        -d "{\"cmd\":$cmd,\"method\":\"$method\",\"sessionId\":\"$sid\",\"language\":\"en\"$extra}" \
        "$X28_BASE" 2>/dev/null
}

# hn_x28_field <json> <key> — extract a JSON string field (values are ASCII here).
x28_field() {
    printf '%s' "$1" | sed -n "s/.*\"$2\":\"\([^\"]*\)\".*/\1/p" | head -1
}

x28_linkstate() {
    local d401 d113
    d401=$(x28_api 401 GET)
    d113=$(x28_api 113 GET)
    [ -n "$d401" ] || { echo "error=api_unreachable"; return 1; }
    printf 'operator=%s\n' "$(x28_field "$d401" network_operator)"
    printf 'tech=%s\n'     "$(x28_field "$d401" network_type_str)"
    printf 'signal=%s\n'   "$(x28_field "$d401" signal_lvl)"
    printf 'rsrp=%s\n'     "$(x28_field "$d401" RSRP)"
    printf 'rsrp_5g=%s\n'  "$(x28_field "$d401" RSRP_5G)"
    printf 'flow_dl=%s\n'  "$(x28_field "$d401" flow_dl)"
    printf 'flow_ul=%s\n'  "$(x28_field "$d401" flow_ul)"
    # PLMN via AT+COPS? (best-effort; empty when the modem is busy).
    local at
    at=$(x28_api 270 POST ',"atInfo":"QVQrQ09QUz8="')
    printf 'plmn=%s\n' "$(printf '%s' "$at" | sed -n "s/.*COPS: [01],2,'\([0-9]*\)'.*/\1/p" | head -1)"
}

x28_linkstate
