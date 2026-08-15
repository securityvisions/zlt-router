#!/bin/sh
# Proxy status monitor - alerts only on state change
. /etc/tg.conf 2>/dev/null || exit 1
. /root/hnlib.sh 2>/dev/null || exit 1
STATE=/tmp/hyst_state
NODE="Proxy"

# label active node(s) from the current PassWall tcp_node config
NODE_ID="$(uci -q get passwall.@global[0].tcp_node)"
case "$NODE_ID" in
	Socks_*) NODE_ID="$(uci -q get passwall."${NODE_ID#Socks_}".node)" ;;
esac
if [ -n "$NODE_ID" ]; then
	proto="$(uci -q get passwall."$NODE_ID".protocol)"
	if [ "$proto" = "_urltest" ]; then
		members=""
		for m in $(uci -q get passwall."$NODE_ID".urltest_node); do
			r="$(uci -q get passwall."$m".remarks)"
			[ -n "$r" ] && members="${members:+$members, }$r"
		done
		[ -n "$members" ] && NODE="Auto ($members)"
	else
		r="$(uci -q get passwall."$NODE_ID".remarks)"
		[ -n "$r" ] && NODE="$r"
	fi
fi

ps=$(hn_sys_proxy_state)   # "up|<latency>" or "down|"
now=${ps%%|*}
case "$now" in up) now="UP";; *) now="DOWN";; esac

old=$(cat "$STATE" 2>/dev/null)
if [ -z "$old" ]; then
	echo "$now" > "$STATE"
	exit 0
fi

if [ "$now" != "$old" ]; then
	if [ "$now" = "DOWN" ]; then
		/root/tg.sh "🔴 ${NODE} is DOWN (proxy unreachable)"
	else
		t=${ps##*|}
		/root/tg.sh "🟢 ${NODE} is UP (${t}s)"
	fi
	echo "$now" > "$STATE"
fi