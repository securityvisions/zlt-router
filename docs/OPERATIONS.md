# Operations

How the deployed system is scheduled, configured, queried, and rolled back.

## Cron schedule (all times Iran, after the timezone fix)

```
*/5  * * * *  /root/hyst.sh                # proxy state-change alert (REALITY-443-parsa default, hysteria2 fallback)
*/30 * * * *  /root/tg.sh --disk           # disk alert (>85%)
*/15 * * * *  /root/balance.sh --monitor   # realtime balance depletion monitor
*    * * * *  /root/devicewatch.sh         # new-device alert
*    * * * *  /root/botcmd-start.sh        # bot keep-alive guard
0    7 * * *  /root/balance.sh --daily     # balance report + snapshot + tier alert
30  21 * * *  /root/usage.sh --report      # daily usage + cost report
55  23 * * *  /root/usage.sh --snapshot    # nightly usage snapshot (feeds monthly bill)
0    7 1 * *  /root/monthly.sh             # previous month's bill
0    9 * * 5  /root/friday.sh              # Friday-discount reminder
```

Boot (`/etc/rc.local`): reboot alert (`tg.sh --reboot`) + bot start (`botcmd-start.sh`).

## Config files (all root-only on the router)

| File | Contents |
|---|---|
| `/etc/tg.conf` | `TOKEN`, `CHAT_ID` (Telegram bot) |
| `/etc/samantel.conf` | `SAMANTEL_PHONE`, `SAMANTEL_PASS`, balance thresholds (`BALANCE_WARN_GB`, `BALANCE_URGENT_GB`, `BALANCE_WARN_DAYS`, `BALANCE_URGENT_DAYS`, `BALANCE_RATE_ALERT_GBH`, `MONITOR_REFRESH_MIN`) |
| `/etc/billing.conf` | `RATE_FULL_TOMAN`, `RATE_FRIDAY_TOMAN`, `ROUND`, `LAST_FRIDAY`, `FRIDAY_REMINDER` |
| `/etc/config/adblock` | blocklist feeds, enabled |
| `/etc/config/sqm` | CAKE rates (download 35000, upload 10000 kbit/s) |
| `/etc/config/system` | timezone `Asia/Tehran` |
| `/etc/config/passwall` | proxy nodes: `REALITY-443-parsa` (VLESS+REALITY, default `tcp_node`) + `hysteria2-11609` (manual fallback) |

## Proxy default

PassWall's global TCP node is **REALITY-443-parsa** (VLESS+REALITY, server `85.121.124.158:443`, SNI `www.bing.com`), served by the VPS's sing-box core. There is no automatic node failover — the **hysteria2-11609** node (server `216.45.52.132:11609`) stays available to select manually. If the VLESS node dies, the **fail-open watchdog** (`passwall-failopen.sh` + `passwall-autorecover.sh`) moves the network to direct internet and restores PassWall automatically once the node is healthy again. UDP follows TCP.

To switch to **hysteria2** manually: `uci set passwall.@global[0].tcp_node='skWrAzdt' && uci commit passwall && /etc/init.d/passwall restart`. To restore the full pre-change PassWall config: `tar xzf /root/passwall-vless-prechange-*.tar.gz -C / && /etc/init.d/passwall restart`.

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
