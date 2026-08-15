#!/bin/sh
# Unit tests: Router API /link — X28 link state endpoint.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
. "$HERE/lib.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

printf 'TOKEN=t\n' > "$TMP/conf"
export RA_CONF="$TMP/conf"
export HTTP_X_ROUTER_TOKEN=t

cat > "$TMP/linkstate" <<EOF
operator=IR - MCI Wap
tech=5G(NSA)
signal=4
rsrp=-77
rsrp_5g=-92
band=
flow_dl=3441.61
flow_ul=243.88
plmn=43211
EOF
export RA_LINK_STATE="$TMP/linkstate"

out=$(run_route GET /link "")
assert_json_eq "link full" '{"operator":"IR - MCI Wap","tech":"5G(NSA)","signal":4,"rsrp":-77,"rsrp_5g":-92,"band":"","plmn":"43211","flow":{"dl":3441.61,"ul":243.88}}' "$(route_body "$out")"

# Unavailable link -> 500.
export RA_LINK_STATE="$TMP/nonexistent"
out=$(run_route GET /link "")
assert_json_eq "link unavailable" '{"error":"link unavailable"}' "$(route_body "$out")"
[ "$(route_status "$out")" = "500" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - link unavailable status"; }

summary
