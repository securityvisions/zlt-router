# Operations

How the deployed system is scheduled, configured, queried, and rolled back.

## Cron schedule (all times Iran, after the timezone fix)

```
*/5  * * * *  /root/hyst.sh                # proxy state-change alert (active tcp_node label)
*/30 * * * *  /root/tg.sh --disk           # disk alert (>85%)
*/15 * * * *  /root/balance.sh --monitor   # realtime balance depletion monitor
*    * * * *  /root/devicewatch.sh         # new-device alert
*    * * * *  /root/botcmd-start.sh        # bot keep-alive guard
0    7 * * *  /root/balance.sh --daily     # balance report + snapshot + tier alert
30  21 * * *  /root/usage.sh --report      # daily usage + cost report
55  23 * * *  /root/usage.sh --snapshot    # nightly usage snapshot (feeds monthly bill)
0    7 1 * *  /root/monthly.sh             # previous month's bill
0    9 * * 5  /root/friday.sh              # Friday-discount reminder
0    * * * *  /root/snap.sh                # hourly telemetry snapshot (Xirouter charts)
```

Boot (`/etc/rc.local`): reboot alert (`tg.sh --reboot`) + bot start (`botcmd-start.sh`).

## Config files (all root-only on the router)

| File | Contents |
|---|---|
| `/etc/tg.conf` | `TOKEN`, `CHAT_ID` (Telegram bot) |
| `/etc/routerapp.conf` | `TOKEN` (Xirouter Router API — the app sends it as `X-Router-Token`) |
| `/etc/samantel.conf` | `SAMANTEL_PHONE`, `SAMANTEL_PASS`, balance thresholds (`BALANCE_WARN_GB`, `BALANCE_URGENT_GB`, `BALANCE_WARN_DAYS`, `BALANCE_URGENT_DAYS`, `BALANCE_RATE_ALERT_GBH`, `MONITOR_REFRESH_MIN`) |
| `/etc/billing.conf` | `RATE_FULL_TOMAN`, `RATE_FRIDAY_TOMAN`, `ROUND`, `LAST_FRIDAY`, `FRIDAY_REMINDER` |
| `/etc/config/adblock` | blocklist feeds, enabled |
| `/etc/config/sqm` | CAKE rates (download 55000, upload 10000 kbit/s — tuned to MCI 5G, 55/10 Mbps) |
| `/etc/config/system` | timezone `Asia/Tehran` |
| `/etc/config/passwall` | proxy nodes: `cdn_ws` (VLESS+WS via Cloudflare, default `tcp_node`) + `eFCgnGrZ` (REALITY) + `hyst_vps` (Hysteria2) |

## Proxy default

PassWall's global TCP node is **cdn-ws** (VLESS+WS over TLS, server `cdn.dmbz.ir:443`, SNI `cdn.dmbz.ir`, path `/v1/status`), fronted by Cloudflare and routed to the VPS origin. It is the reliable default because Cloudflare's anycast IPs are not subject to the same ISP interference as the direct VPS IP. **REALITY-443-parsa** (VLESS+REALITY, server `85.121.124.158:443`, SNI `www.bing.com`) is kept as the alternate node, and **hysteria2-vps-31800** (Hysteria2, server `85.121.124.158:31800/UDP`, salamander obfuscation) is available to select manually. UDP follows TCP.

If the active node dies, the **fail-open watchdog** (`passwall-failopen.sh` + `passwall-autorecover.sh`, both versioned in `router/`) moves the network to direct internet and restores PassWall automatically once the node is healthy again.

To switch nodes manually:
```
uci set passwall.@global[0].tcp_node='cdn_ws'   # or eFCgnGrZ (REALITY) / hyst_vps (Hysteria2)
uci commit passwall && /etc/init.d/passwall restart
```

## Script source of truth

Every script that runs on the router has a canonical copy in `router/` in this repo (same deal as hnlib/botlib). Edit the repo copy and deploy; never edit on the router directly. The one exception is the PassWall health trio, whose live copy may be hot-fixed over SSH during an incident — if so, pull it back into the repo afterwards.

| Repo path | Router path | Notes |
|---|---|---|
| `router/usage.sh` | `/root/usage.sh` | per-device usage CLI (`--today --raw --month --names --name --resolve --snapshot`) |
| `router/balance.sh` | `/root/balance.sh` | Samantel balance report/monitor |
| `router/billing.sh` | `/root/billing.sh` | cost/bill text tables |
| `router/botcmd.sh` | `/root/botcmd.sh` | Telegram bot (long polling) |
| `router/botcmd-start.sh` | `/root/botcmd-start.sh` | bot keep-alive guard |
| `router/botlib.sh` | `/root/botlib.sh` | pure rendering helpers |
| `router/hnlib.sh` | `/root/hnlib.sh` | shared business module (balance reader, cost table, system state) |
| `router/tg.sh` | `/root/tg.sh` | alert CLI wrapper |
| `router/devicewatch.sh` | `/root/devicewatch.sh` | new-device + watchlist alerts |
| `router/snap.sh` | `/root/snap.sh` | hourly telemetry snapshot |
| `router/friday.sh` | `/root/friday.sh` | Friday-discount reminder |
| `router/hyst.sh` | `/root/hyst.sh` | proxy state-change alert |
| `router/monthly.sh` | `/root/monthly.sh` | previous month's bill |
| `router/passwall-failopen.sh` | `/root/passwall-failopen.sh` | fail-open watchdog (minute cron) |
| `router/passwall-autorecover.sh` | `/root/passwall-autorecover.sh` | auto-recovery (3-min cron) |
| `router/passwall-bypass-ensure.sh` | `/root/passwall-bypass-ensure.sh` | direct-domain nftset re-attach (minute cron) |
| `router/routerapi.sh` | `/www/cgi-bin/routerapi.sh` | Router API CGI dispatcher |
| `router/routerapi_lib.sh` | `/www/cgi-bin/routerapi_lib.sh` | Router API JSON builders |

## VPS proxy server (s-ui)

The VPS at `85.121.124.158` runs the **s-ui** panel with a sing-box core (replacing the former x-ui/xray panel):

- **Panel**: `http://85.121.124.158:2095/app/` — admin credentials set via the CLI (`sui admin`); stored on the server, never in this repo
- **Subscription**: `http://85.121.124.158:2096/sub/<client-name>`
- **Inbounds**: VLESS+REALITY on 443 (dest/SNI `www.bing.com`), Hysteria2 on 31800/UDP (salamander obfuscation, self-signed TLS)
- **Management**: `/usr/local/s-ui/sui` (`admin`, `setting`, `uri`, `backup`, `help`)
- **Firewall (ufw)**: 22, 443, 2095 (panel), 2096 (sub), 31800 udp+tcp open

**Never commit these secrets to the repo** — they live only on the router.

## Runtime state

- `/tmp/` — logs (`tg.log`, `botcmd.log`, `balance.log`), states (`hyst_state`, `devices_known`, `balance_tier`, `balance_anchor`, `balance_rate`, `samantel_token`), bot guard (`botcmd.lock`, `botcmd.pid`), adblock blocklist.
- `/etc/usage-log/` — nlbw baseline (`last`) + monthly usage logs.
- `/etc/balance-log/` — daily balance snapshots (drain-rate source).
- `/etc/telemetry/` — `hourly.log` (hourly `ts|total_gb|balance_gb|proxy_state` rows + trailing quality fields: latency, passive Mbps, active node — see the cron table) for the Xirouter charts.

## Router API (Xirouter app)

The app talks to `http://192.168.1.1/cgi-bin/routerapi.sh/*` with header `X-Router-Token: <token>`
(see `docs/adr/0002-router-json-api.md`). Test from the LAN:

```sh
curl -H 'X-Router-Token: <token>' http://192.168.1.1/cgi-bin/routerapi.sh/status
curl -u xirouter:<token> http://192.168.1.1/cgi-bin/routerapi.sh/balance
```

Deploy: copy `router/routerapi.sh` + `router/routerapi_lib.sh` from this repo to `/www/cgi-bin/`
and `router/hnlib.sh` to `/root/hnlib.sh`, `chmod 755`, and write `/etc/routerapp.conf`
(`TOKEN=...`, chmod 600). Requires `jq` (already installed for the bot). Auth is HTTP Basic
(`xirouter:<token>`) — uhttpd drops custom `X-*` headers. `hnlib.sh` is the one shared business
module (balance report reader + cost table) sourced by the bot, the telemetry snapshot, the
billing report and the Router API. Contract: `~/router-app/API_CONTRACT.md`.

## Useful commands (from the router)

```sh
# bot status
cat /tmp/botcmd.pid && kill -0 $(cat /tmp/botcmd.pid) && echo alive

# balance
/root/balance.sh --report     # rich report
/root/balance.sh --daily      # send report + tier check
/root/balance.sh --monitor    # realtime estimate + tier check

# usage / billing
/root/usage.sh --today        # today's per-device usage
/root/usage.sh --month        # monthly log
/root/billing.sh --today no   # cost table, full rate
/root/billing.sh --month yes  # cost table, Friday rate

# adblock
/etc/init.d/adblock restart
nslookup doubleclick.net 127.0.0.1   # expect NXDOMAIN

# sqm
tc qdisc show dev wan | grep cake      # upload shaping
tc qdisc show dev ifb4wan | grep cake  # download shaping

# timezone
date                       # should show IRST
crontab -l                 # list schedules
```

## Cron schedule (live)

| When | Job | What it does |
|---|---|---|
| every minute | `passwall-failopen.sh` | fail-open + quality-aware node rotation |
| every minute | `passwall-bypass-ensure.sh` | re-attach direct-domain nftset |
| every 3 min | `passwall-autorecover.sh` | auto-recovery |
| every 5 min | `x28watch.sh` | link stickiness + degradation watchdog (operator re-select) |
| every 10 min | `vpshealth.sh` | VPS origin probes (panel/sub) + alert |
| hourly | `snap.sh` | telemetry row `ts\|total_gb\|balance_gb\|proxy_state\|latency\|passive_mbps\|node` |
| 03:00 daily | `backup.sh` | config snapshot of AX3000T + X28 vendor export |
| 06:30 daily | `speedtest.sh` | Cloudflare measure + degradation alert |
| 07:00 daily | `balance.sh --daily` | balance report + tier warning |
| 21:30 daily | usage + cost report | per-device usage (Toman) |
| every 30 min | disk space | alert above 85% |
| 1st of month 07:00 | `monthly.sh` | previous month's bill |
| Friday 09:00 | `friday.sh` | Friday-discount reminder |

## Troubleshooting

| Symptom | Check |
|---|---|
| No bot replies | `cat /tmp/botcmd.log`; bot process alive? restart: `/root/botcmd-start.sh` |
| Balance says "check credentials/network" | `/etc/samantel.conf` phone/password; internet up; try `/root/balance.sh --report` manually |
| Balance estimate off | Expected — ISP counter lags. Monitor re-anchors every 60 min; margins/rate alert cover it |
| Adblock not blocking | `/etc/init.d/adblock restart`; `logread | grep adblock`; feeds reachable? |
| Latency still spikes | SQM rates may need tuning to the real plan (`uci set sqm.eth1.download/upload`) |
| "collecting data" in balance report | Normal for the first few days until nightly snapshots accumulate |
| Friday reminder not firing | `/fridayremind on`; check `/etc/crontabs/root`; confirm `date` shows IRST and day is Friday |

## Rollback

Each piece is independently reversible:

- **Bot/alerts**: remove `/root/{tg,botcmd,botcmd-start,hyst,devicewatch}.sh` + the cron lines + the `rc.local` lines
- **Usage/billing**: remove `/root/{usage,billing,monthly}.sh` + cron lines + `/etc/billing.conf` + `/etc/usage-log/`
- **Balance**: restore the previous `balance.sh`, remove the `--monitor` and `--daily` cron lines, remove `/etc/balance-log/`
- **Adblock**: `apk del adblock luci-app-adblock` (frees ~0.8 MB, restores RAM)
- **SQM**: `uci set sqm.eth1.download=0` (or restore prior values) + restart SQM
- **Timezone**: set `system.@system[0].zonename='UTC'`, `timezone='GMT0'`, restart system + cron
