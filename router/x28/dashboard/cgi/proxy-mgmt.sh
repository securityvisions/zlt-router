#!/bin/sh
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo ""

JQ=/data/proxy/jq
CTRL="http://127.0.0.1:9090"
action="${QUERY_STRING:-}"

case "$action" in
    list*)
        # GET /api/proxy-mgmt.sh?list → all proxies in auto group + rescue pool
        auto=$(curl -s -m 6 "$CTRL/proxies/auto" 2>/dev/null)
        members=$(printf '%s' "$auto" | "$JQ" -r '.all // [] | .[]' 2>/dev/null)
        now=$(printf '%s' "$auto" | "$JQ" -r '.now // "?"' 2>/dev/null)
        echo "{\"active\":\"$now\",\"nodes\":["
        first=1
        for m in $members; do
            alive=$(curl -s -m 5 "$CTRL/proxies/$m" 2>/dev/null | "$JQ" -r '.alive // "false"' 2>/dev/null)
            ptype=$(curl -s -m 5 "$CTRL/proxies/$m" 2>/dev/null | "$JQ" -r '.type // "?"' 2>/dev/null)
            [ "$first" = "0" ] && echo ","
            printf '{"name":"%s","alive":%s,"type":"%s"}' "$m" "$alive" "$ptype"
            first=0
        done
        echo "]}"
        ;;
    test*)
        # GET /api/proxy-mgmt.sh?test=<node> → fire delay check
        node="${action#test=}"
        url_encoded="https%3A%2F%2Fwww.gstatic.com%2Fgenerate_204"
        result=$(curl -s -m 12 "$CTRL/proxies/$(printf '%s' "$node" | sed 's/ /%20/g')/delay?url=$url_encoded&timeout=8000" 2>/dev/null)
        delay=$(printf '%s' "$result" | "$JQ" -r '.delay // "error"' 2>/dev/null)
        printf '{"node":"%s","delay":%s}' "$node" "$delay"
        ;;
    switch*)
        # POST body: {"name":"<node>"} → switch auto group to this node
        body=$(cat)
        node=$(printf '%s' "$body" | "$JQ" -r '.name // ""' 2>/dev/null)
        [ -z "$node" ] && { echo '{"error":"no node specified"}'; exit 0; }
        resp=$(curl -s -m 10 -X PUT "$CTL/proxies/auto" \
            -H 'Content-Type: application/json' \
            -d "{\"name\":\"$node\"}" 2>/dev/null)
        printf '{"ok":true,"switched_to":"%s"}' "$node"
        ;;
    add*)
        # POST body: {"uri":"vless://...|vmess://..."} → convert and add to rescue pool
        body=$(cat)
        uri=$(printf '%s' "$body" | "$JQ" -r '.uri // ""' 2>/dev/null)
        [ -z "$uri" ] && { echo '{"error":"no URI provided"}'; exit 0; }
        # run converter on the single URI
        tmpf=$(mktemp)
        printf '%s\n' "$uri" > "$tmpf"
        RESCUE_RAW="$tmpf" sh /data/proxy/rescue-convert.sh > "${tmpf}.out" 2>/dev/null
        count=$("$JQ" -r '.proxies | length' "${tmpf}.out" 2>/dev/null || echo 0)
        if [ "$count" = "0" ]; then
            rm -f "$tmpf" "${tmpf}.out"
            printf '{"ok":false,"message":"URI could not be parsed into a valid proxy"}'
            exit 0
        fi
        # append new nodes to existing provider file
        existing=$("$JQ" -r '.proxies | length' /data/proxy/mihomo/rescue-pool.yaml 2>/dev/null || echo 0)
        "$JQ" -s '.[0].proxies += .[1].proxies | .[0]' \
            /data/proxy/mihomo/rescue-pool.yaml "${tmpf}.out" > /data/proxy/mihomo/rescue-pool.yaml.new 2>/dev/null
        mv /data/proxy/mihomo/rescue-pool.yaml.new /data/proxy/mihomo/rescue-pool.yaml
        rm -f "$tmpf" "${tmpf}.out"
        # hot-reload the provider
        curl -s -m 10 -X PUT "http://127.0.0.1:9090/providers/proxies/rescue-pool" >/dev/null 2>&1 || true
        printf '{"ok":true,"message":"added %d node(s), total %d in rescue pool"}' "$count" "$((existing + count))"
        ;;
    reload)
        curl -s -m 10 -X PUT "$CTRL/providers/proxies/rescue-pool" >/dev/null 2>&1
        printf '{"ok":true}'
        ;;
    *)
        printf '{"error":"unknown action"}'
        ;;
esac
exit 0
