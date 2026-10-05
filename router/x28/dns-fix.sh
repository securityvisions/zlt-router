#!/bin/sh
# dns-fix.sh — Facade delegating to x28-dns.sh
HERE="$(dirname "$0")"
DNS_SH="$HERE/x28-dns.sh"
[ -f "$DNS_SH" ] || DNS_SH="/data/proxy/x28-dns.sh"

exec sh "$DNS_SH" "${1:-auto}"
