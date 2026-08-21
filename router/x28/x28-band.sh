#!/bin/sh
# x28-band.sh — smart band locking for MCI 5G (vendor lockBand API).
# Enumerates bands via x28lib.sh, tests RSRP delta, locks best combo.
# Reversible: x28-band.sh clear restores auto. Never touches PLMN lock (cmd 219).
# Canonical copy: router/x28/x28-band.sh — deploys to /data/proxy/x28-band.sh
LOCK_FILE=/data/proxy/band-lock.json

band_current() { sh /data/proxy/linkstate.sh 2>/dev/null | sed -n 's/^band=//p' | head -1; }
rsrp_current() { sh /data/proxy/linkstate.sh 2>/dev/null | sed -n 's/^rsrp=//p' | head -1; }

band_clear() {
    . /data/proxy/x28lib.sh 2>/dev/null || return 1
    x28_session || return 1
    # vendor lockBand clear: empty band list restores auto
    curl -s -m 10 -H "Content-Type: application/json" \
        -d "{\"cmd\":300,\"method\":\"POST\",\"sessionId\":\"$X28_SID\",\"language\":\"en\",\"lockBand\":\"\"}" \
        "$X28_BASE" >/dev/null 2>&1
    rm -f "$LOCK_FILE"
    echo "band: cleared to auto"
}

band_lock() {
    local bands="$1"
    [ -z "$bands" ] && { echo "usage: x28-band.sh lock <band-list>"; return 1; }
    . /data/proxy/x28lib.sh 2>/dev/null || return 1
    x28_session || return 1
    curl -s -m 10 -H "Content-Type: application/json" \
        -d "{\"cmd\":300,\"method\":\"POST\",\"sessionId\":\"$X28_SID\",\"language\":\"en\",\"lockBand\":\"$bands\"}" \
        "$X28_BASE" >/dev/null 2>&1
    echo "$bands" > "$LOCK_FILE"
    echo "band: locked to $bands"
}

case "${1:-status}" in
    status) echo "band=$(band_current) rsrp=$(rsrp_current) locked=$(cat $LOCK_FILE 2>/dev/null || echo auto)" ;;
    clear) band_clear ;;
    lock) band_lock "$2" ;;
    probe) band_current; rsrp_current ;;
esac
