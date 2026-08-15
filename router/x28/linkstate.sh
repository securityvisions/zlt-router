#!/bin/sh
# linkstate.sh — ZLT X28 link-state reader.
#
# Canonical copy lives in this repo (router/x28/linkstate.sh); it deploys to
# the X28 as /data/proxy/linkstate.sh and to the AX3000T as /root/x28link.sh
# (beside x28lib.sh in each place). Reads the vendor JSON API and emits one
# key=value line per field:
#
#   operator   network operator name (e.g. "IR - MCI Wap", "Rightel")
#   plmn       serving PLMN (e.g. 43211) — empty when the modem scan is busy
#   tech       technology (5G(NSA) / 4G / 4G+ / ...)
#   signal     vendor signal level (0-5, UI scale)
#   rsrp       LTE anchor RSRP in dBm (empty when not reported)
#   rsrp_5g    5G NR RSRP in dBm (empty when not on NSA)
#   band       serving band — NOT exposed by this firmware (always empty; kept
#              in the schema so a future firmware/API that reports it can fill it)
#   flow_dl    session download MB
#   flow_ul    session upload MB
#
# Shared API helpers come from x28lib.sh in the same directory.

. "${X28_LIB:-$(dirname "$0")/x28lib.sh}"

x28_linkstate() {
    local d401 at
    d401=$(x28_api 401 GET)
    [ -n "$d401" ] || { echo "error=api_unreachable"; return 1; }
    printf 'operator=%s\n' "$(x28_field "$d401" network_operator)"
    printf 'tech=%s\n'     "$(x28_field "$d401" network_type_str)"
    printf 'signal=%s\n'   "$(x28_field "$d401" signal_lvl)"
    printf 'rsrp=%s\n'     "$(x28_field "$d401" RSRP)"
    printf 'rsrp_5g=%s\n'  "$(x28_field "$d401" RSRP_5G)"
    printf 'band=%s\n'     "${X28_BAND:-}"
    printf 'flow_dl=%s\n'  "$(x28_field "$d401" flow_dl)"
    printf 'flow_ul=%s\n'  "$(x28_field "$d401" flow_ul)"
    # PLMN via AT+COPS? (best-effort; empty when the modem is busy).
    at=$(x28_api 270 POST ',"atInfo":"QVQrQ09QUz8="')
    printf 'plmn=%s\n' "$(printf '%s' "$at" | sed -n "s/.*COPS: [01],2,'\([0-9]*\)'.*/\1/p" | head -1)"
}

x28_linkstate
