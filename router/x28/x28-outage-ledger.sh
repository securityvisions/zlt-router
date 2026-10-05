#!/bin/sh
# x28-outage-ledger.sh — Outage Ledger (SLA) facade delegating to outage-ledger.sh.
set -eu
HERE="$(dirname "$0")"
OUTAGE_SH="$HERE/outage-ledger.sh"
[ -f "$OUTAGE_SH" ] || OUTAGE_SH="/data/proxy/outage-ledger.sh"
[ -f "$OUTAGE_SH" ] || OUTAGE_SH="/root/outage-ledger.sh"

exec sh "$OUTAGE_SH" "$@"
