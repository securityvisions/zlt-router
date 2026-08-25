def num: tonumber? // 0;
. as $in |
((($in.add // "") | type) == "string") and
(($in.id // "") | test("^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$"))
| select(.)
| {
    type: "vmess",
    name: ("rc-vm " + (($in.ps // "") | tostring | .[0:40])),
    server: $in.add,
    port: (($in.port | tostring | num) | floor),
    uuid: ($in.id | ascii_downcase),
    alterId: (($in.aid // 0) | num | floor),
    security: ((($in.scy // "auto") | tostring)),
    network: ({tcp:"tcp",ws:"ws",h2:"http",grpc:"grpc"}[$in.net // "tcp"] // "tcp"),
    udp: true,
    tls: ($in.tls == "tls"),
    servername: ((($in.sni // "")) | tostring)
  }
| select(.port > 0 and .port < 65536)
| select(.network == "tcp" or .network == "ws" or .network == "http" or .network == "grpc")
| if .network == "ws" or .network == "http"
  then . + {"ws-opts": ({"path": ((($in.path // "/")) | tostring)} +
        (if ($in.host // "") != "" then {"headers": {"Host": ($in.host | tostring)}} else {} end))}
  else . end
| if .network == "grpc"
  then . + {"grpc-opts": {"grpc-service-name": ((.path // "") | tostring)}}
  else . end
| del(.path, .host)
