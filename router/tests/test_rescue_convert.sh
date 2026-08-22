#!/bin/sh
# Unit tests: rescue-convert — all-8 protocol fixtures + hostile corpus.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
CONV="$HERE/../x28/rescue-convert.sh"

PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n' "$2"; printf '  actual: [%s]\n' "$3"; fi; }
assert_contains() { if printf '%s' "$3" | grep -qF "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (missing: $2)"; fi; }
assert_not_contains() { if printf '%s' "$3" | grep -qF "$2"; then FAIL=$((FAIL+1)); echo "FAIL - $1 (unexpected: $2)"; else PASS=$((PASS+1)); fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

run() { RESCUE_RAW="$TMP/in.txt" MAX_LINES="${MAXL:-300}" sh "$CONV" 2>/dev/null; }
count() { printf '%s' "$1" | jq '.proxies | length' 2>/dev/null; }

UUID1="11111111-2222-3333-4444-555555555555"
UUID2="aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
PBK="q3vN2xQ8mZtR5yWcJ7hKdP0sVbXfLgAe9uT4iMoYwEr"

# ---------- vless / reality ----------
cat > "$TMP/in.txt" <<EOF
vless://$UUID1@example.com:443?encryption=none&security=reality&sni=www.bing.com&fp=chrome&pbk=$PBK&sid=abcd1234&type=tcp#MyReality
EOF
out=$(run)
assert_eq "vless-reality count" "1" "$(count "$out")"
assert_contains "vless-reality type" '"type":"vless"' "$out"
assert_contains "vless-reality server" '"server":"example.com"' "$out"
assert_contains "vless-reality port" '"port":443' "$out"
assert_contains "vless-reality uuid" "\"uuid\":\"$UUID1\"" "$out"
assert_contains "vless-reality pbk" "\"public-key\":\"$PBK\"" "$out"
assert_contains "vless-reality sid" '"short-id":"abcd1234"' "$out"
assert_contains "vless-reality name kept" "MyReality" "$out"

# plain vless tcp no tls, with vision -> dropped (vision needs tls)
cat > "$TMP/in.txt" <<EOF
vless://$UUID1@1.2.3.4:80?encryption=none&security=none&flow=xtls-rprx-vision#dropme
EOF
out=$(run); assert_eq "vision-without-tls dropped" "0" "$(count "$out")"

# vless ws+tls valid
cat > "$TMP/in.txt" <<EOF
vless://$UUID1@cdn.example.net:443?encryption=none&security=tls&sni=cdn.example.net&type=ws&host=cdn.example.net&path=%2Fws#WSNode
EOF
out=$(run)
assert_eq "vless-ws count" "1" "$(count "$out")"
assert_contains "vless-ws network" '"network":"ws"' "$out"
assert_contains "vless-ws path" '"path":"/ws"' "$out"
assert_contains "vless-ws host header" '"Host":"cdn.example.net"' "$out"

# bad uuid dropped
printf 'vless://not-a-uuid@1.2.3.4:443?type=tcp\n' > "$TMP/in.txt"
out=$(run); assert_eq "bad uuid dropped" "0" "$(count "$out")"

# ---------- trojan ----------
cat > "$TMP/in.txt" <<EOF
trojan://Str0ngPass!@trojan.example.org:9443?sni=trojan.example.org&allowInsecure=0#TJ
EOF
out=$(run)
assert_eq "trojan count" "1" "$(count "$out")"
assert_contains "trojan password" '"password":"Str0ngPass!"' "$out"
assert_contains "trojan sni" '"sni":"trojan.example.org"' "$out"

# ---------- shadowsocks ----------
# SIP002 urlsafe b64 of aes-256-gcm:test1234
SS_B64=$(printf 'aes-256-gcm:test1234' | base64 | tr '+/' '-_' | tr -d '=')
printf 'ss://%s@1.3.5.7:8388#SS1\n' "$SS_B64" > "$TMP/in.txt"
out=$(run)
assert_eq "ss sip002 count" "1" "$(count "$out")"
assert_contains "ss cipher" '"cipher":"aes-256-gcm"' "$out"
assert_contains "ss password" '"password":"test1234"' "$out"

# legacy whole-uri b64 of chacha20:legacypass@9.9.9.9:9999
LEG=$(printf 'chacha20-ietf-poly1305:legacypass@9.9.9.9:9999' | base64 | tr -d '=')
printf 'ss://%s#Legacy\n' "$LEG" > "$TMP/in.txt"
out=$(run)
assert_eq "ss legacy count" "1" "$(count "$out")"
assert_contains "ss legacy server" '"server":"9.9.9.9"' "$out"

# unknown plugin dropped
PLUGIN_ENC=$(printf 'obfs-local;obfs=http' | sed 's/;/%3B/g')
printf 'ss://%s@1.3.5.7:8388?plugin=%s#PLG\n' "$SS_B64" "$PLUGIN_ENC" > "$TMP/in.txt"
out=$(run)
assert_contains "ss obfs plugin accepted" '"plugin":"obfs"' "$(RESCUE_RAW="$TMP/in.txt" sh "$CONV" 2>/dev/null)"

{ printf 'ss://%s@1.3.5.7:8388?plugin=' "$SS_B64"; printf 'v2ray-plugin%%2Bshadowtls'; printf '#X\n'; } > "$TMP/in.txt"
out=$(run); assert_eq "unknown plugin dropped" "0" "$(count "$out")"

# ---------- hysteria2 / hy2 ----------
printf 'hy2://authpass123@5.6.7.8:36712/?obfs=salamander&obfs-password=obfspass&sni=hy.example.com#HY2\n' > "$TMP/in.txt"
out=$(run)
assert_eq "hy2 count" "1" "$(count "$out")"
assert_contains "hy2 auth" '"auth":"authpass123"' "$out"
assert_contains "hy2 obfs" '"obfs":"salamander"' "$out"
assert_contains "hy2 obfs-password" '"obfs-password":"obfspass"' "$out"

# hysteria v1 scheme must not map to hysteria2
printf 'hysteria://authpass@5.6.7.8:36712?sni=x#V1\n' > "$TMP/in.txt"
out=$(run); assert_not_contains "hysteria v1 not mapped to hysteria2" '"type":"hysteria2"' "$out"

# ---------- tuic / juicity ----------
printf 'tuic://%s:tupass@7.7.7.7:443?congestion_control=bbr&alpn=h3&sni=tu.example.com&TU\n' "$UUID2" > "$TMP/in.txt"
out=$(run)
assert_eq "tuic count" "1" "$(count "$out")"
assert_contains "tuic uuid" "\"uuid\":\"$UUID2\"" "$out"
assert_contains "tuic cc" '"congestion-controller":"bbr"' "$out"
assert_contains "tuic alpn" '"alpn":["h3"]' "$out"

printf 'juicity://%s:jp@7.7.7.7:8443?congestion_control=cubic#JUI\n' "$UUID2" > "$TMP/in.txt"
out=$(run)
assert_eq "juicity count" "1" "$(count "$out")"
assert_contains "juicity type" '"type":"juicity"' "$out"

# bad congestion control dropped
printf 'tuic://%s:x@7.7.7.7:443?congestion_control=weird\n' "$UUID2" > "$TMP/in.txt"
out=$(run); assert_eq "bad cc dropped" "0" "$(count "$out")"

# ---------- vmess ----------
VM_JSON='{"add":"vm.example.io","port":"443","id":"'"$UUID1"'","aid":"0","scy":"auto","net":"ws","host":"vm.example.io","path":"/vm","tls":"tls","ps":"VMNode"}'
VM_B64=$(printf '%s' "$VM_JSON" | base64 -w0 2>/dev/null || printf '%s' "$VM_JSON" | base64)
printf 'vmess://%s\n' "$VM_B64" > "$TMP/in.txt"
out=$(run)
assert_eq "vmess count" "1" "$(count "$out")"
assert_contains "vmess server" '"server":"vm.example.io"' "$out"
assert_contains "vmess network" '"network":"ws"' "$out"
assert_contains "vmess ws path" '"path":"/vm"' "$out"
assert_contains "vmess tls" '"tls":true' "$out"

# vmess garbage b64 dropped
printf 'vmess://not_base64!!\n' > "$TMP/in.txt"
out=$(run); assert_eq "vmess garbage dropped" "0" "$(count "$out")"

# ---------- hostile corpus ----------
{
  printf 'vless://%s@%s:443?type=tcp\n' "$UUID1" "$(head -c 300 /dev/zero | tr '\0' 'a')"
  for i in $(seq 1 20); do printf 'totally:not:a:scheme:%d\n' "$i"; done
  printf 'ss://%%zz@@bad:70000\n'
  printf 'vless://%s@[::gg]:443?type=tcp\n' "$UUID1"
  printf '# comment line\n'
  printf '\n'
} > "$TMP/in.txt"
out=$(run)
assert_eq "hostile: nothing survives" "0" "$(count "$out")"

# cap enforcement (>MAX_NODES distinct nodes → only MAX_NODES emitted)
MAXNODE_TEST=8
{ for i in $(seq 1 15); do
    printf 'vless://%s@10.0.%d.%d:443?type=tcp#N%d\n' "$UUID1" $((i/250)) $((i%250)) "$i"
  done; } > "$TMP/in.txt"
out=$(MAX_NODES=$MAXNODE_TEST run)
assert_eq "cap enforced" "$MAXNODE_TEST" "$(count "$out")"

# dedupe: same identity twice → one node
cat > "$TMP/in.txt" <<EOF
vless://$UUID1@1.2.3.4:443?type=tcp#A
vless://$UUID1@1.2.3.4:443?type=tcp#B
EOF
out=$(run); assert_eq "dedupe same identity" "1" "$(count "$out")"

summary
