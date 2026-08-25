#!/bin/sh
# rescue-convert.sh — collected proxy URIs -> mihomo provider payload (JSON).
#
# Input : file of URIs (one per line) or '-' for stdin.
# Output: {"proxies":[…]} — JSON is a YAML subset; consumed as the rescue
#         provider file directly.
#
# Protocols (all 8): vless/reality, trojan, shadowsocks (SIP002 + legacy),
# hysteria/hy2, tuic, juicity  -> parsed by the embedded strict-awk engine.
# vmess (base64 JSON)          -> parsed by jq (strict typed filter).
#
# Safety model: allowlist grammar per protocol; ANY violation silently drops
# that one candidate. Hard caps: MAX_LINES input, LINE_MAX per line,
# MAX_NODES emitted. Deterministic rc-N names. Never touches owned configs.
#
# Env seams: RESCUE_RAW, MAX_LINES=300, MAX_NODES=60, LINE_MAX=2048.
set -u

RESCUE_RAW="${RESCUE_RAW:-/data/proxy/rescue/raw/collected.txt}"
MAX_LINES="${MAX_LINES:-300}"
MAX_NODES="${MAX_NODES:-60}"
LINE_MAX="${LINE_MAX:-2048}"
JQ="${JQ_BIN:-$(command -v jq || echo /data/proxy/jq)}"
CONV_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo /data/proxy)"

SRC="${1:-$RESCUE_RAW}"
[ "$SRC" = "-" ] && SRC=/dev/stdin

TMPD=$(mktemp -d 2>/dev/null || mktemp -d "${TMPDIR:-/tmp}/rc.XXXXXX")
KEEP="${KEEP:-0}"
[ "$KEEP" = "1" ] || trap 'rm -rf "$TMPD"' EXIT

# ---- pass 1: URI-shaped protocols via strict awk engine --------------------
awk -v maxlines="$MAX_LINES" -v linemax="$LINE_MAX" -v maxnodes="$MAX_NODES" '
function initb64(   i,c){
    for(i=0;i<64;i++){
        c=substr("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",i+1,1); _B[c]=i
        c=substr("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_",i+1,1); _B[c]=i
    }
    _B["="]=0
}
function b64dec(s,   n,i,v,out,b1,b2,b3,pad,c){
    if(length(s)==0) return ""
    while(length(s)%4!=0) s=s"="
    n=length(s)
    pad=0; out=""
    if(index(s,"-")||index(s,"_")){ gsub(/-/,"+",s); gsub(/_/,"/",s) }
    for(i=1;i<=n;i++){
        c=substr(s,i,1)
        if(!(c in _B)) return ""
        if(c=="="){
            pad++
            if(i<=n-2) return ""
        } else {
            if(pad) return ""
        }
        v=_B[c]
        k=(i-1)%4
        if(k==0){b1=v}
        else if(k==1){b2=v}
        else if(k==2){b3=v}
        else{
            out=out sprintf("%c",b1*4+int(b2/16))
            if(pad<2) out=out sprintf("%c",(b2%16)*16+int(b3/4))
            if(pad<1) out=out sprintf("%c",(b3%4)*64+v)
        }
    }
    return out
}
function hexv(c){ return index("0123456789abcdef",tolower(c))-1 }
function urldec(s,   out,i,c,h1,h2){
    out=""
    for(i=1;i<=length(s);i++){
        c=substr(s,i,1)
        if(c=="%"&&i+2<=length(s)){
            h1=hexv(substr(s,i+1,1)); h2=hexv(substr(s,i+2,1))
            if(h1>=0&&h2>=0){ out=out sprintf("%c",h1*16+h2); i+=2; continue }
        }
        if(c=="+") c=" "
        out=out c
    }
    return out
}
function getq(q,key,   a,i,n,kv){
    n=split(q,a,"&")
    for(i=1;i<=n;i++){ kv[1]=""; split(a[i],kv,"="); if(kv[1]==key) return urldec((index(a[i],"=")?substr(a[i],index(a[i],"=")+1):"")) }
    return ""
}
function clean(s){ gsub(/"/,"",s); gsub(/\\/,"",s); gsub(/^[[:space:]]+|[[:space:]]+$/,"",s); return substr(s,1,48) }
function vhost(h){ if(length(h)==0||length(h)>253) return 0; if(h~/^[A-Za-z0-9._-]+$/) return 1; if(h~/^\[[0-9A-Fa-f:]+\]$/) return 1; return 0 }
function vuuid(u){ return u~/^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$/ }
function J(s){ gsub(/\\/,"\\\\",s); gsub(/"/,"\\\"",s); gsub(/\t/,"\\t",s); gsub(/\r/,"\\r",s); gsub(/\n/,"\\n",s); return "\"" s "\"" }
function emit(o){ printf "%s\n", o }

function p_vless(uuid,host,port,q,name,   sec,net,sni,fp,pbk,sid,flow,path,hh,svc,o){
    if(!vuuid(uuid)) return
    sec=getq(q,"security"); if(sec=="")sec="none"
    if(sec!="none"&&sec!="tls"&&sec!="reality")return
    flow=getq(q,"flow")
    if(flow!=""&&flow!="none"&&flow!="xtls-rprx-vision")return
    net=getq(q,"type"); if(net=="")net="tcp"
    if(net!="tcp"&&net!="ws"&&net!="grpc"&&net!="http")return
    sni=getq(q,"sni"); fp=getq(q,"fp")
    o="{\"type\":\"vless\",\"server\":" J(host) ",\"port\":" port ",\"udp\":true,\"uuid\":" J(tolower(uuid))
    if(net!="tcp") o=o ",\"network\":" J(net=="h2"?"http":net)
    if(sec!="none"){
        o=o ",\"tls\":true"
        if(sni!="") o=o ",\"servername\":" J(sni)
        if(fp!="")  o=o ",\"client-fingerprint\":" J(fp)
        if(sec=="reality"){
            pbk=getq(q,"pbk"); sid=getq(q,"sid")
            if(pbk=="")return
            o=o ",\"reality-opts\":{\"public-key\":" J(pbk) (sid!=""?",\"short-id\":" J(sid):"") "}"
        }
    } else if(flow=="xtls-rprx-vision") return
    if(flow=="xtls-rprx-vision") o=o ",\"flow\":\"xtls-rprx-vision\""
    if(net=="ws"||net=="http"){
        path=getq(q,"path"); hh=getq(q,"host")
        o=o ",\"" ((net=="ws")?"ws-opts":"http-opts") "\":{\"path\":" J(path==""?"/":path) (hh!=""?",\"headers\":{\"Host\":" J(hh) "}":"") "}"
    } else if(net=="grpc"){
        svc=getq(q,"serviceName"); o=o ",\"grpc-opts\":{\"grpc-service-name\":" J(svc) "}"
    }
    emit(o ",\"name\":" J(name) "}")
}
function p_trojan(pass,host,port,q,name,   sni,o){
    if(length(pass)==0||length(pass)>256)return
    if(pass~/[[:space:]]/)return
    o="{\"type\":\"trojan\",\"server\":" J(host) ",\"port\":" port ",\"password\":" J(pass)
    sni=getq(q,"sni"); if(sni!="")o=o ",\"sni\":" J(sni)
    if(getq(q,"allowInsecure")=="1"||getq(q,"allow_insecure")=="1") o=o ",\"skip-cert-verify\":true"
    emit(o ",\"name\":" J(name) "}")
}
function p_hy2(auth,host,port,q,name,   obfs,op,sni,o){
    if(length(auth)==0||length(auth)>256)return
    auth=urldec(auth)
    if(auth~/[[:space:]]/)return
    o="{\"type\":\"hysteria2\",\"server\":" J(host) ",\"port\":" port ",\"auth\":" J(auth) ",\"udp\":true"
    obfs=getq(q,"obfs"); op=getq(q,"obfs-password")
    if(obfs!=""){ if(obfs!="salamander")return; o=o ",\"obfs\":\"salamander\"" (op!=""?",\"obfs-password\":" J(op):"") }
    sni=getq(q,"sni"); if(sni!="")o=o ",\"sni\":" J(sni)
    if(getq(q,"insecure")=="1"||getq(q,"allow_insecure")=="1") o=o ",\"skip-cert-verify\":true"
    emit(o ",\"name\":" J(name) "}")
}
function p_tj(kind,uid,pwd,host,port,q,name,   cc,alpn,sni,o){
    if(!vuuid(uid))return
    pwd=urldec(pwd)
    if(length(pwd)==0||length(pwd)>256)return
    if(pwd~/[[:space:]]/)return
    o="{\"type\":" J(kind) ",\"server\":" J(host) ",\"port\":" port ",\"uuid\":" J(tolower(uid)) ",\"password\":" J(pwd)
    cc=getq(q,"congestion_control"); if(cc=="")cc=getq(q,"congestion-control")
    if(cc!=""){ if(cc!~/^(bbr|cubic|new_reno)$/)return; o=o ",\"congestion-controller\":" J(cc) }
    alpn=getq(q,"alpn"); if(alpn!="")o=o ",\"alpn\":[" J(alpn) "]"
    sni=getq(q,"sni"); if(sni!="")o=o ",\"sni\":" J(sni)
    if(getq(q,"insecure")=="1"||getq(q,"allow_insecure")=="1") o=o ",\"skip-cert-verify\":true"
    emit(o ",\"name\":" J(name) "}")
}
function p_ss(userinfo,host,port,q,name,   du,mp,meth,pwd,plg,o){
    if(!vhost(host))return
    du=b64dec(userinfo)
    if(du==""){ du=userinfo }              # plain method:password variant
    mp=index(du,":")
    if(mp<=1)return
    meth=substr(du,1,mp-1); pwd=substr(du,mp+1)
    if(meth!~/^[a-z0-9+-]+$/||length(meth)>32)return
    if(index(pwd,":")>0 && meth=="2022"){ } # 2022 ciphers carry : in pwd — allowed
    if(length(pwd)==0||length(pwd)>512)return
    o="{\"type\":\"ss\",\"server\":" J(host) ",\"port\":" port ",\"cipher\":" J(meth) ",\"password\":" J(pwd)
    plg=getq(q,"plugin")
    if(plg!=""){
        plg=urldec(plg)
        if(plg~/^obfs-local/){
            o=o ",\"plugin\":\"obfs\",\"plugin-opts\":{\"mode\":" J((getq(q,"obfs-mode")!=""?getq(q,"obfs-mode"):"http")) "}"
        } else return                    # unsupported plugin -> drop candidate
    }
    emit(o ",\"name\":" J(name) "}")
}
BEGIN{ initb64(); nodes=0; lines=0 }
{
    lines++
    if(lines>maxlines) exit 0
    sub(/\r$/,"")
    if(length($0)==0 || $0 ~ /^#/) next
    if(length($0)>linemax) next
    line=$0
    sp=index(line,"://")
    if(sp==0) next
    scheme=tolower(substr(line,1,sp-1))
    rest=substr(line,sp+3)
    frag=""; fp=index(rest,"#")
    if(fp>0){ name=urldec(substr(rest,fp+1)); rest=substr(rest,1,fp-1) } else name=""
    qp=index(rest,"?")
    q=""; if(qp>0){ q=substr(rest,qp+1); rest=substr(rest,1,qp-1) }
    sub(/\/$/,"",rest); sub(/^\//,"",rest)
    at=0
    for(i=length(rest);i>=1;i--){ if(substr(rest,i,1)=="@"){at=i;break} }
    user=""; hp=rest
    if(at>0){ user=substr(rest,1,at-1); hp=substr(rest,at+1) }
    if(scheme=="ss" && at==0 && index(hp,":")==0){
        du=b64dec(hp)
        la=0
        for(i=length(du);i>=1;i--){ if(substr(du,i,1)=="@"){la=i;break} }
        if(la>0){
            user=substr(du,1,la-1)
            hp=substr(du,la+1)
        }
    }
    chp=-1
    bracketq=(index(hp,"[")>0)
    for(i=length(hp);i>=1;i--){ if(substr(hp,i,1)==":"){chp=i;break} }
    if(chp<=0) next
    host=substr(hp,1,chp-1)
    port=substr(hp,chp+1)
    sub(/\/.*$/, "", port)
    if(!vhost(host)) next
    if(port !~ /^[0-9]{1,5}$/ || port+0<1 || port+0>65535) next
    nodes++
    if(nodes>maxnodes) exit 0
    pfx=""
    if(name!="") pfx=" " clean(name)
    nm="rc-" nodes pfx
    if(scheme=="vless"||scheme=="reality")      p_vless(user,host,port,q,nm)
    else if(scheme=="trojan")                   p_trojan(user,host,port,q,nm)
    else if(scheme=="hy2"||scheme=="hysteria2") p_hy2(user,host,port,q,nm)
    else if(scheme=="hysteria"){ }
    else if(scheme=="tuic"){ split(user,u2,":"); p_tj("tuic",u2[1],substr(user,index(user,":")+1),host,port,q,nm) }
    else if(scheme=="juicity"){ split(user,u3,":"); p_tj("juicity",u3[1],substr(user,index(user,":")+1),host,port,q,nm) }
    else if(scheme=="ss")                       p_ss(user,host,port,q,nm)
    else if(scheme=="socks"||scheme=="http"){ } # collector never emits; ignore
    # vmess handled outside (see shell)
}' "$SRC" > "$TMPD/uri.ndjson" || true

# ---- pass 2: vmess via jq (strict, typed) ----------------------------------
grep '^vmess://' "$SRC" 2>/dev/null | head -"$MAX_NODES" | while IFS= read -r v; do
    printf '%s' "$v" | cut -c9- | tr '_-' '/+' | {
        read -r payload
        case "$payload" in *'=') ;; *) pad=$(( (4 - ${#payload} % 4) % 4 )); [ $pad -ne 0 ] && payload="$payload$(printf '=%.0s' $(seq 1 $pad))" ;; esac
        printf '%s' "$payload"
    } | "$JQ" -rR '@base64d' 2>/dev/null | "$JQ" -ce -f "${CONV_DIR}/rescue-vmess.jq" >> "$TMPD/uri.ndjson" || true
done

# ---- assemble provider payload (dedupe + cap) ------------------------------
"$JQ" -sc '
    map(select(. != null))
    | unique_by([.type, .server, .port, (.uuid // .password // "")])
    | .[:'"$MAX_NODES"']
    | { proxies: . }
' "$TMPD/uri.ndjson"
