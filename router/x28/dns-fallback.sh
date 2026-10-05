#!/bin/sh
# dns-fallback.sh — Legacy facade delegating to x28-dns.sh isp
HERE="$(dirname "$0")"
DNS_SH="$HERE/x28-dns.sh"
[ -f "$DNS_SH" ] || DNS_SH="/data/proxy/x28-dns.sh"

exec sh "$DNS_SH" isp
