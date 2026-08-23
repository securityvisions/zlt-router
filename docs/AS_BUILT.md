# AS-BUILT SPECIFICATION — Home Network Control Plane (X28 era)

**Snapshot date:** 2026-08-22 · **Rev 2** (post `x28-always-up` reliability batch; rev 1 facts superseded where noted) · **Method:** live inspection of running systems (read-only SSH, controller APIs, packet/filter dumps) cross-checked against the canonical repo (`~/home-network`). Statements are **CONFIRMED** unless tagged INFERRED / UNVERIFIED.
**Scope:** exactly what exists and runs today. No proposals, no redesigns.

---

## 1. System Identity and Purpose

One cellular CPE acts as the entire home network's WAN edge, LAN gateway, WiFi AP, transparent-proxy engine, DNS/DHCP server, monitoring plane, and Telegram control plane:

- **ZLT X28** (`192.168.70.1`) — MediaTek MT6890 5G CPE running vendor-built **OpenWrt 19.07-SNAPSHOT** (`r0-aefbe500`, target `mt6890/evb6890v1_64_cpe_nand`, arch `aarch64_cortex-a55_neon-vfpv4`, kernel `4.19.205`, BusyBox 1.30.1). Holds the **Samantel SIM**, camps on **MCI 5G NSA (PLMN 43211)**, falls back to **Rightel (43220)**. Boot slot `a` of an A/B layout (`bootslot=a` on kernel cmdline).
- A second router, **Xiaomi AX3000T** (`192.168.1.1`), is **bricked / offline** (ping from workstation: unreachable). All former AX3000T duties (WiFi, PassWall, nlbwmon, cron watchers, Router API) are dormant; the X28 absorbed them.
- A **VPS** (`85.121.124.158`) terminates the censorship-bypass tunnel: sing-box core behind the **s-ui** panel (`:2095`), inbound **VLESS+Reality :443** and **Hysteria2 :31800**.

Everything custom lives under `/data/proxy` on the X28 and mirrors to `~/home-network/router/x28/` in git (branch `main`, HEAD `66690e4` at inspection).

## 2. Topology (observed)

```
                    [Samantel SIM]   PLMN 43211 MCI 5G NSA (fallback 43220 Rightel)
                           │ LTE/NR data bearers (ql_mipc)
        ┌──────────────────┼───────────────────────┐
        ▼                  ▼                       ▼
    ccmni1 (UP)        ccmni2 (UP)            ccmni3 (UP, /8 oddity)
 22.75.228.183/28   22.113.7.146/29         22.104.25.152/8
        │ MASQ ▲            │ MASQ                (no route use)
        │      └── default route: "default dev ccmni1 scope link" (main + table 17000)
        ▼
╔═══════════════════════ ZLT X28 — 192.168.70.1 ═════════════════════╗
║  nat  PREROUTING(br0) → X28_SPLIT:                                 ║
║        RETURN dst 185.137.27.122 | RETURN dst 192.168.70.0/24 |    ║
║        REDIRECT tcp → :12345                                       ║
║  mangle PREROUTING(br0) → X28_NOQUIC: DROP udp dport 443           ║
║                                                                    ║
║  dnsmasq :53 ──server=127.0.0.1#5353──► mihomo DNS (DoH 8.8.8.8    ║
║    │ adblock.conf (address= denies)      via auto group)           ║
║    ▼                                                               ║
║  br0 192.168.70.1/24 ─┬─ eth0.1 eth0.2 eth0.3 eth1   (LAN ports)   ║
║                       ├─ ra0 (2.4G SSID)  rai0 (5G SSID)  ← active ║
║                       └─ ra1-3, rai1-3              (spare, down)  ║
║  mihomo :12345 ─ rules ─┬─ DIRECT (IR/academic/private) → ccmni1    ║
║  mixed :1080            └─ "auto" url-test → vps-reality           ║
║  ctrl :9090 (localhost)               85.121.124.158:443 Reality   ║
╚═══════════════════════════════│════════════════════════════════════╝
                                │ VLESS+Reality over MCI
                                ▼
                 [VPS 85.121.124.158]
                  sing-box core :443 (Reality, sni www.bing.com)
                  Hysteria2 :31800 (salamander) · s-ui panel :2095
```

**LAN clients (DHCP leases, `/tmp/dnsmasq.leases`):**

| Hostname | MAC | IP | Notes |
|---|---|---|---|
| Samsung | `c8:12:0b:32:7c:f2` | 192.168.70.155 | |
| Nothing-Phone-2 | `3a:7e:c0:54:29:d9` | 192.168.70.106 | locally-administered MAC (🎲) |
| parsavisions | `f4:28:9d:60:61:cb` | 192.168.70.141 | Windows laptop; runs a WSL2-class Linux env (eth0 `172.22.226.175/20` gw `172.22.224.1`) that reaches the X28 through it |

**Offline:** AX3000T `192.168.1.1` (bricked). **Legacy on-box:** `v2raya` still runs and listens `:2017` (unused by any current traffic path).

## 3. Component Inventory

| Component | Role | Platform / version | Mgmt addr | Key interfaces | Persistent state |
|---|---|---|---|---|---|
| ZLT X28 | WAN edge, gateway, AP, proxy, DNS/DHCP, monitor, bot | OpenWrt 19.07-SNAPSHOT vendor / kernel 4.19.205 / MT6890 | ssh/telnet/web 192.168.70.1 | br0, ra0/rai0, ccmni1-3 | `/data` (ubi, 287 MB), `/overlay` |
| VPS `85.121.124.158` | Tunnel exit (Reality/Hy2), s-ui panel | Debian-class, sing-box + s-ui (versions UNVERIFIED from here) | `:2095` panel (form login) | eth0 | s-ui DB on VPS |
| AX3000T | *none today* (bricked) | OpenWrt 25.12.5 (pre-brick) | unreachable | — | — |
| Laptop `parsavisions` | admin workstation, agent host, **independent tunnel watchdog vantage** | Windows + WSL2 Linux (systemd user session) | WiFi DHCP .141 | wlan→X28 | repo `~/home-network`; watcher state in `~/.cache` |
| Workstation watcher (`sb-selfheal`) | second-vantage core self-heal: probes full tunnel every 60 s; after 2 dead minutes fires panel `restartSb` directly, falling back to SSH-relaying the X28 one-shot heal | POSIX-sh + systemd user timer `x28-sb-selfheal.timer` | — | — | `~/.cache/x28-sb-selfheal{.log,/}`, creds `~/home-network/.secrets/sui-heal.conf` (0600, git-ignored) |
| Telegram bot `@xirouterbot` | remote control / alerts | POSIX-sh script | via Bot API through tunnel | — | `/data/proxy/bot-state/offset` |

## 4. Configuration Source-of-Truth Map

| Subsystem | Persistent source | Generated / runtime | Consumer | Precedence notes |
|---|---|---|---|---|
| LAN IP / bridge members | **vendor NVRAM via `lan_mgr`** (not uci) | `ip`/brctl live state | kernel | uci `network.lan.ipaddr='192.168.1.1'` is IGNORED at runtime — actual br0 is `192.168.70.1` |
| DHCP server | **generated `/tmp/dnsmasq.conf`** (lan_mgr) + `dns-fix.sh` appends | same file; leases `/tmp/dnsmasq.leases` | dnsmasq (pid file `/tmp/dnsmasq.pid`, user `admin`) | uci dhcp values (start 100/limit 150/12 h) differ from generated (`.100–.200`, 24 h); generated wins |
| DNS upstream | `dns-fix.sh` decision (tunnel↔ISP) | appended lines in `/tmp/dnsmasq.conf`: `server=127.0.0.1#5353` + `no-resolv` (current) or ISP `server=` lines | dnsmasq → mihomo :5353 | vendor `/tmp/resolv.conf` (10.201.112.252, 217.218.127.127) is the ISP-mode source |
| Ad-block | `/data/proxy/adblock/adblock-update.sh` output | `/data/proxy/adblock/adblock.conf` (`address=/…/` ×~93 k, 2.8 MB) | dnsmasq `conf-file=` | weekly age-based refresh |
| Transparent-proxy firewall | **device-only** `/data/proxy/tproxy-fixed-enable.sh` (runs at boot + net-hotplug) | live iptables nat/mangle | kernel | repo copies `tproxy-enable/stage2-*` exist but are NOT what rc.local runs |
| Proxy engine config | **device-only** `/data/proxy/mihomo/config.yaml` (0600; real creds) | in-process | mihomo | repo copy is a redacted template; deploy seeds only if absent |
| Management firewall | `harden.sh` (repo canonical) | live `X28_MGMT` chain + INPUT jump | kernel | rebuilt at every boot (idempotent) |
| Bot identity/state | `/etc/tg.conf` (TOKEN, CHAT_ID — 0600) + `/data/proxy/bot-state/offset` | `/tmp/x28bot/{bot.pid,hb,hb.log}` | x28-bot.sh | offset persists across reboot by design |
| Operator policy | constants inside `operator-watchdog.sh` (43211 pref / 43220 fb; **interval 60 s**, bounce-after 2 rounds) | `/tmp/x28-watchdog/*`, `/data/proxy/watchdog.log` | watchdog daemon | |
| VPS heal targets | `/etc/sui-heal.conf` (PANEL_HOST/PORT/USER/PASS — 0600) | cookie jar in /tmp | x28-vps-heal.sh | one-shot mode sources the conf itself (fixed in always-up 06) |
| Maintenance window | decision constants inside hnlib (`hn_maint_should_reboot`: Sunday, hour 5, ≥14 d uptime or <60 MB free) | `/data/proxy/maint/{window-marker,skew-alert-stamp}` | x28-maint.sh loop | clock-skew guard uses HTTP Date over the direct path |
| Config-drift guard | tracked-set constant + whitelist inside `x28-drift.sh` | `/data/proxy/drift/{last-good.sha,pending.sha,last-run,snapshots/}` | x28-drift.sh loop | last-good advances only via `ack` |
| Boot repair policy | `hn_boot_repair_plan` mapping in hnlib (health FAIL names → ordered actions) | computed per boot | x28-boot-doctor.sh | upstream-only failures produce no local repair |
| VPS heal targets | `/etc/sui-heal.conf` (PANEL_HOST/PORT/USER/PASS — 0600) | cookie jar in /tmp | x28-vps-heal.sh | |
| Balance creds/thresholds | `/etc/samantel.conf` (PHONE/PASS/WARN/URGENT_GB/DAYS/RATE_ALERT_GBH/MONITOR_REFRESH_MIN — 0600) | `/tmp/samantel_token` (28 d), `/tmp/samantel_packages.json`, guarded cache `/tmp/balance_report(.ts)` | balance.sh, bot, budget | cache write guarded: only text matching `"GB left across"` persists |
| Owners (person map) | `/data/proxy/owners.conf` (0600, `mac|person`) — EXISTS, both entries → `parsa` | read at daily-roll | usage-collect, x28-people | |
| Outage ledger | created on first incident | `/data/proxy/outage-ledger.log` (`epoch|down/up`) — **absent today** (no outage recorded yet) | ledger script/bot | |
| WiFi share creds | `/data/proxy/wifi.conf` — **ABSENT** (feature dormant, graceful card) | — | x28-wifi.sh | |
| Cloudflare tunnel | `/etc/tunnel.conf` + `/data/proxy/cloudflared` — **ABSENT** (stub loop waits) | — | x28-tunnel.sh | |
| Telemetry history | append-only `/data/proxy/usage/telemetry.log` (prune ≤5000) | same | digest, charts, hn_quality_series | **two writers, two schemas** (see §13) |

## 5. X28 Deep-Dive

### 5.1 Platform & storage layout

Kernel cmdline (abridged): `console=ttyS0,921600n1 root=/dev/ubiblock0_0 rootfstype=squashfs ubi.mtd=29 … bootslot=a androidboot.hardware=mt6890`.

| Mount | Device | Size / use | Survives reboot | Purpose |
|---|---|---|---|---|
| `/` (squashfs+`/overlay` ubi0_1) | mtd29/… | 22.8 M, 4 % used | yes | rootfs; `/root/*.sh` helpers live here |
| `/data` (ubi1_2, ubifs) | mtd50 user_data | 287.6 M, **58 % used** | yes | ALL custom stack: `/data/proxy/**` |
| `/mnt/data` (yaffs2) | user_config | 10 M | yes | vendor config incl. `tzcfg/dhcp_hosts` |
| `/customer` (ubi1_1) | — | 90 M, ~empty | read-only-ish | unused by us |
| `/mnt/vendor/{nvcfg,nvdata,nvram,…}` | yaffs2 | 8–32 M each | yes | vendor radio/config (SSID lives here; no nvram CLI exposed) |
| `/tmp` (tmpfs) | RAM | 312 M | **no** | dnsmasq conf/leases, tokens, bot runtime, watchdog state, balance cache |

`rc.local` also contains a self-heal block: if `/dev/ubi1` is missing it reformats `mtd/user_data`, re-attaches, recreates volumes `customer`(100 MiB)+`data`(rest), then `mount -a`.

### 5.2 Boot sequence (actual)

1. Vendor modem bring-up chain (`S002ccci_fsd → S003ccci_mdinit → S15firmware.sh → S20network → S22mtk_netagent → S85ql_netd/ql_ril_service → S99mipc_wan.init`) creates `ccmni*`, applies NVRAM LAN config (br0 192.168.70.1), starts `lan_mgr` (regenerates `/tmp/dnsmasq.conf`, `/tmp/resolv.conf`).
2. `S50qos` installs vendor mangle QoS chains.
3. Custom services in rc.d order:
   - `S95done` → runs **`/etc/rc.local`**: dropbear keygen + `dropbear :22`; `telnetd :23`; `harden.sh` (builds `X28_MGMT`); **`tproxy-fixed-enable.sh`** (builds `X28_SPLIT` + `X28_NOQUIC`); **`dns-fix.sh`** (picks tunnel/ISP DNS mode); background `x28-boot-alert.sh`.
   - `S95x28-thermal` (guard + 60 s telemetry writer) · `S95x28-usage` (conntrack collector).
   - `S96atci/atcid/led` (vendor) · **`S96x28-bot`** (supervise) · **`S96x28-telemetry`** (hourly loop) · **`S96x28-vps-heal`**.
   - **`S97x28-adblock`** (weekly-refresh loop) · `S97x28-tunnel` (stub wait-loop) · **`S97x28-maint`** (maintenance-window loop) · **`S97x28-drift`** (nightly backup/drift loop).
   - **`S98x28proxy`** → procd starts **mihomo** (`respawn 3600 5 5`).
   - `S99v2raya` (legacy UI), `S99vnstat`, **`S99x28-watchdog`** (operator watchdog), **`S99x28-boot-doctor`** (one-shot verifier, fires ~90 s after start), `S99zmtk_boot_done`.
4. Hotplug `net/30-x28-proxy.sh` (`ACTION=add`): sleep 3 → re-run `tproxy-fixed-enable.sh` + `dns-fix.sh` (self-heals interface churn).
5. No crontab exists (`/etc/crontabs/root` empty); all periodic work is procd/shell loops.

### 5.3 Interfaces

| Iface | State | Addr / role |
|---|---|---|
| br0 | UP, `98:a9:42:6b:67:b8`, 192.168.70.1/24 | LAN bridge: eth0.1-3, eth1, ra0, rai0 (ra1-3/rai1-3 down spares) |
| eth0 / eth0.1-3 / eth1 | eth0 UP (parent of VLAN subs); eth0.4 DOWN | wired ports |
| ra0 / rai0 | UP, master br0 | 2.4 G / 5 G BSSIDs (vendor-managed, no uci wireless, no iw/iwinfo/nvram CLI) |
| ccmni1 | UP, 22.75.228.183/28 | **default egress** (`default dev ccmni1 scope link`), MASQ |
| ccmni2 | UP, 22.113.7.146/29 | secondary bearer, MASQ rule exists |
| ccmni3 | UP, 22.104.25.152/**8** | connected-route only; unused (vendor artifact) |
| apcli0/apclii0, tunl/gre/vti/ifb… | DOWN | unused |

Policy routing: `ip rule` 17000 for `from/to 192.168.70.0/24 → table 17000` (default → ccmni1, LAN → br0). `net.ipv4.ip_forward=1`.

### 5.4 Firewall / packet pipeline (live `iptables-save`)

Built-in policies are **ACCEPT everywhere** (uci `firewall` defaults say forward REJECT, but no fw3 zone chains exist in the live ruleset — vendor `*_mdl_chain`s plus our custom chains own it).

- **nat**
  - `PREROUTING`: `prerouting_mdl_chain` (empty) → `-i br0 -j X28_SPLIT`
  - `X28_SPLIT`: `RETURN` dst `185.137.27.122/32` (VPS panel) → `RETURN` dst `192.168.70.0/24` → `REDIRECT tcp --to-ports 12345`
  - `POSTROUTING`: `postrouting_mdl_chain` → `MASQUERADE -o ccmni1`, `MASQUERADE -o ccmni2`
- **filter INPUT** (all ACCEPT policy): `parental_input_mdl_chain`(empty) → `input_mdl_chain` (**from ccmni1 only:** DROP tcp 22/80/443, DROP icmp-echo) → tcp dports 22/23/2017 → **`X28_MGMT`** (`RETURN` lo/LAN else DROP — built by `harden.sh`) → ddos syn/ack chains.
- **filter FORWARD**: `parental_forward_mdl_chain`(empty) → `forward_mdl_chain` (`-i br0` INVALID-drop; global `TCPMSS clamp-to-PMTU`) → `flow`(empty).
- **mangle PREROUTING**: `-i br0 -j X28_NOQUIC` → **DROP udp dport 443** (forces QUIC→TCP so it can be intercepted); then vendor `qos_Default/qos_Default_ct` CONNMARK classes.
- **ebtables**: installed, all tables empty.

### 5.5 DNS / DHCP end-to-end (current, tunnel mode)

1. Client → DHCP from dnsmasq: range **192.168.70.100–.200 /24 h**, option router=`192.168.70.1`, DNS=`192.168.70.1`, MTU 1500, domain `home` (opt 15), vendor opt-125 tag; static hosts `/mnt/data/etc/tzcfg/dhcp_hosts`; `address=/m.home/` and `/rtm.home/` → 192.168.70.1.
2. Client DNS query → dnsmasq (192.168.70.1:53; also 127.0.0.1:53) → **`server=127.0.0.1#5353` + `no-resolv`** (appended by dns-fix; verified live: `mode=tunnel`) → **mihomo DNS** resolves via DoH `https://8.8.8.8/dns-query#auto` **through the auto proxy group**; ad-block denies answered from `adblock.conf` first.
3. ISP-fallback mode (when tunnel dead): dns-fix strips those two lines and appends `no-resolv` + ISP `server=10.201.112.252` / `217.218.127.127` (values sourced from vendor `/tmp/resolv.conf`), AND inserts a top `-I X28_SPLIT 1 -j RETURN` so **all** LAN TCP bypasses the redirect (true fail-open). Healthy mode deletes that RETURN. Both edits are change-checked (no needless dnsmasq restarts).

### 5.6 Proxy engine — mihomo

Process: `/data/proxy/mihomo/mihomo -d /data/proxy/mihomo` (Mihomo Meta **v1.19.30** arm64, go1.26.6), procd `x28proxy` START=98 respawn 3600 5 5. VSZ ≈ 1.6 GB virtual (Go runtime; RSS modest).

Listeners (confirmed via `netstat`): `192.168.70.1:1080` (mixed SOCKS/HTTP), `192.168.70.1:12345` (redir), `127.0.0.1:5353` (DNS), `127.0.0.1:9090` (REST controller).

Outbound nodes (config 0600; secrets redacted):

| Node | Target | Notes |
|---|---|---|
| vps-reality | `85.121.124.158:443` vless+reality, sni `www.bing.com`, fp chrome, uuid `<redacted>` | primary; udp ok; delay ~770–980 ms |
| cdn-ws | `188.114.98.0:443` vless+ws+tls, host `cdn.dmbz.ir`, path `/v1/status` | alive-flag flaps; explicit delay 1400–1600 ms when origin up |
| hy2 | `85.121.124.158:31800` hysteria2 salamander | UDP-path dependent; observed working 1570 ms after MCI re-register |
| babaii | `216.45.52.132:23993` vless+vision | TCP open since provider host reboot, but handshake fails **with and without** flow — provider rotated something; ticket `needs-info` |

Group `auto`: url-test `https://8.8.8.8/`, interval 60 s, tolerance 100, members [vps-reality, cdn-ws, hy2, babaii]. Verification nuance learned live: right after an engine restart the controller's `alive` flags can read optimistic before first url-test completes — trust the per-node `/delay` endpoint for ground truth.

Rules (exact current order):
```
DOMAIN-SUFFIX,iau.ir,DIRECT          ← SRBIAU/IAU family (stdn2.*, amoozesh*)
DOMAIN-SUFFIX,srbiau.ac.ir,DIRECT
DOMAIN-KEYWORD,amoozesh,DIRECT
DOMAIN-SUFFIX,saymyname.website,DIRECT
IP-CIDR,185.137.27.122/32,DIRECT,no-resolve
IP-CIDR,192.168.0.0/16|10/8|172.16/12,DIRECT,no-resolve
GEOIP,IR,DIRECT
GEOSITE,youtube|google|instagram|facebook,auto
MATCH,auto
```

Domain rules work because clients' DNS traverses mihomo (:5353), giving it the mapping; verified live: fetching `stdn2.iau.ir` from a LAN client shows `chain=DIRECT` in the controller connection table.

Legacy stacks still on disk but **not** in the traffic path: `sing-box/` (53 M), `xray/` (33 M), `xray.stock/` (33 M), `v2raya` (running, `:2017`, 27 M).

### 5.7 Custom services & automation (complete list)

| Service (init) | Body | Trigger/cadence | Actions & state | Failure behavior |
|---|---|---|---|---|
| `x28proxy` (S98) | mihomo | procd daemon | §5.6 | respawn 3600 5 5 |
| `x28-bot` (S96) | `x28-bot.sh supervise` | long-poll `getUpdates?timeout=50`; offset persisted | dispatch commands/Panel taps; `bal_card` cache-fallback; `send_photo` via socks multipart; switches via watchdog one-shot with heartbeat keeper | supervisor kills child if heartbeat (`/tmp/x28bot/hb`, atomic write) age >180 s and respawns; updates older than 600 s skipped (anti-replay) |
| `x28-telemetry` (S96) | hourly `while` loop → `x28-telemetry.sh` | 1 h | appends schema-v1/v2 row via TelemetryStore (prune 5000); then runs budget check | best-effort, errors swallowed |
| `x28-thermal` (S95) | `x28-thermal-loop.sh` | **60 s** | appends `ts\|temp=\|load=\|rsrp=` to the SAME telemetry.log; alerts >75 °C | best-effort |
| `x28-usage` (S95) | `usage-collect.sh loop` | 5 s conntrack deltas (boot-aware) | `day/YYYY-MM-DD` (`mac|ip|name|up|down`); at date-change `roll()`: month totals, **owners roll before 35-day prune**, Friday ≥20:00 Weekly-Digest (ISO-week marker gate), month-end People report (first Fri with Jalali day-of-month ≤3; month-marker gate) | malformed cycles dropped; `.rolled-*` markers prevent doubles |
| `x28-watchdog` (S99) | `operator-watchdog.sh` daemon | **every 60 s**: direct-IP HTTPS probe (endpoints env-overridable via `WATCHDOG_ENDPOINTS`) | 3 strikes → operator switch (cmd 228 via reselect.sh; storm guard ≤3/h, cooldown 600 s); on fallback probes preferred with backoff 2700→10800 s; calls `dns-fix.sh` each cycle; writes Outage Ledger `add-down`/`add-up`; tracks failed switch rounds → after 2 rounds + bounce-cooldown fires the **bearer bounce** (forced re-register on current PLMN via cmd 228 — see `bounce` one-shot mode); Telegram notifies | bounce honors its own cooldown + dry-run envs |
| `x28-vps-heal` (S96) | loop | poll controller `auto` alive | if all nodes dead ≥**4 min** while local DNS :5353 answers → s-ui login (cookie jar) → `POST /app/api/restartSb`, with Telegram cards on heal/skip/fail; one-shot `heal` mode sources `/etc/sui-heal.conf` itself | best-effort; never blocks boot |
| `x28-adblock` (S97) | `adblock-loop.sh` | hourly age-check (>7 d) | `adblock-update.sh`: fetch StevenBlack via socks→direct fallback, convert to `address=` lines, atomic swap, re-run dns-fix | last-known-good list kept on any failure |
| `x28-tunnel` (S97) | stub loop | waits for `/etc/tunnel.conf` + cloudflared binary | no-op today (both absent) | exits silently |
| `x28-maint` (S97) | maintenance-window loop | every 10 min | Sunday hour-05 window: uptime ≥14 d or free RAM <60 MB → warning card → marker → reboot; clock-skew guard (HTTP Date vs direct path) skips+alerts when device clock is off | dry-run + `once` mode |
| `x28-drift` (S97) | config backup/drift loop | hourly age-gate (~20 h) | sha256 critical config set → classify vs last-good → ALERT card naming M/A/D files (SAME-AS-PENDING quiet); bounded snapshot ring (keep 14) under `snapshots/`; `ack` advances last-good | last-good never auto-advances |
| `x28-boot-doctor` (S99, one-shot) | verify+repair ~90 s post-boot | once per boot | health gate GREEN → quiet verdict card; RED → ordered repairs (rules→dns→proxy→watchdog), re-check, single verdict card | pure planner in hnlib; crash found+fixed during live reboot exercise |
| `harden.sh` | rc.local + rerunnable | boot | builds `X28_MGMT`, hooks INPUT jump (dedup) | idempotent |
| `tproxy-fixed-enable.sh` (device-only) | rc.local + net-hotplug | boot/ifadd | builds `X28_SPLIT`, `X28_NOQUIC`, inserts VPS-panel RETURN | disable twin provided (`tproxy-fixed-disable.sh`) |
| `dns-fix.sh` | rc.local, net-hotplug, watchdog cycle, post-switch, adblock-update | event | probe tunnel (SOCKS→egress generate_204, ×2 with sleep 2) → set dnsmasq upstream tunnel/ISP **and** insert/remove top `X28_SPLIT RETURN` (fail-open) | prints `mode=tunnel/isp`; no-op if unchanged |
| `balance.sh` (`/root`) | CLI `--report/--cache/--daily/--check/--monitor` | bot taps, budget tick, monitor | NextAuth login to `pwa.samantel.ir` (CSRF→credentials→Bearer, token cached 28 d), packages JSON caches, tier/rate alerts via `/root/tg.sh`, **guarded cache** (only `"GB left across"` text persists) | failed query never poisons cache; bot falls back with age note |
| Budget Guardian (`x28-budget.sh`) | hourly telemetry tick + on-demand | tiers exhausted<0.05 GB / urgent<3 GB,<3 d,<7 d proj / warn<10 GB,<7 d,<14 d proj | cooldown-gated TG alerts (exhausted bypasses); `/budget` Card incl. drain, projected Toman (busybox-date-hardened), Jalali exhaustion date | missing data → honest "no data" card |
| Outage Ledger (`x28-outage-ledger.sh`) | watchdog hooks + `/outages` | on transitions | append-only `epoch|kind`, idempotent; pairing/monthly-Jalali totals in hnlib. **First pair recorded 2026-08-22 22:17→22:20 (2 m12 s)** — from the controlled bearer-bounce exercise | file created lazily |
| People/Owners/Digest/WiFi scripts | bot + roll integration | as above | see §4 map | graceful cards when inputs missing |

Shared libraries: `/data/proxy/hnlib.sh` **and** `/root/hnlib.sh` (identical pushes) — pure functions (Jalali, tiers, outage pairing, health score, cooldown, owner lookup, quality module); `/data/proxy/jq` static binary; `tg-notify.sh` (best-effort sendMessage via `socks5h://192.168.70.1:1080`); `/root/tg.sh` (AX-era card sender used by balance.sh).

### 5.8 Management surfaces

| Surface | Addr | Auth | Reachable from | Can change |
|---|---|---|---|---|
| SSH (dropbear) | `:22` all-ifaces | root password (host-key alg must include ssh-rsa) | LAN + WAN(WAN-side dropped by input_mdl/X28_MGMT for ccmni ingress) | everything |
| Telnet | `:23` | root shell, no password | LAN only (X28_MGMT) | everything (deliberate break-glass, rc.local) |
| Vendor web UI | `:80` / `:443` (mini_httpd, cgipat `cgi-bin/*`) | vendor login | LAN (WAN-side 80/443 dropped) | radio/SSID, operator, config export (cmd 180) |
| Vendor JSON API | `http://192.168.70.1/cgi-bin/http.cgi` | cmd 232 session token → cmd 100 login (`sha256(token+pass)`) → `sessionId` | LAN (scripts use it) | operator select cmd 228; traffic counters cmd 18; **cmd 219 (PLMN lock) is forbidden by house policy** |
| v2rayA UI | `:2017` | its own | LAN only (X28_MGMT) | legacy, unused |
| mihomo REST | `127.0.0.1:9090` | none (localhost bind) | device-local (SSH) | proxies/rules/conns read; per-node `/delay` ground-truth tests; node select |
| Telegram bot | api.telegram.org via `socks5h://192.168.70.1:1080` | allowlisted CHAT_ID in `/etc/tg.conf` | anywhere the phone has Telegram | status read-outs; operator switch; owner assign; wifi share; digests |
| Watchdog one-shots | CLI on device | root | SSH | `switch <plmn>` · `bounce` (forced re-register, dry-run env honored) |
| Serial console | ttyS0 921600 8N1 | physical | board pads | U-Boot/recovery (AX3000T-style UART path applies here too) |

### 5.9 Workstation-vantage components (new)

- **`vps/sb-selfheal.sh` + systemd user timer** (`x28-sb-selfheal.timer`, every ~60 s): probes the tunnel end-to-end from the laptop (`socks5h://192.168.70.1:1080` → gstatic 204). Two dead minutes with a reachable panel → direct `restartSb`; if that leg fails (observed: panel returns empty reply to this vantage on that endpoint only), SSH-relays to the X28 and runs its one-shot heal. Crash-loop cap ≥4 restarts/15 min.
- Creds: `~/home-network/.secrets/sui-heal.conf` (0600, git-ignored; symlinked to `~/.config/x28/sui-heal.conf`) — PANEL_* plus X28_SSH_PASS/X28_HOST for the relay.
- Log: `~/.cache/x28-sb-selfheal.log`. State: `~/.cache/x28-sb-selfheal/` (fails counter, restart ring).
- **Staged, not installed:** `vps/sb-selfheal-install.sh` prepares the true VPS-local systemd timer for the day VPS SSH opens (sshd currently publickey-only; device dropbear can't negotiate ed25519).

## 6. End-to-End Traffic Flows (verified)

1. **LAN client → blocked-site HTTPS (YouTube)**: DNS via §5.5 returns real IP; SYN enters br0 → nat PREROUTING `X28_SPLIT` (dst ≠ LAN, ≠ VPS-IP) → **REDIRECT :12345** → mihomo matches `GEOSITE,youtube` → `auto` → **vps-reality** → egress ccmni1 (MASQ) → VPS → internet. Controller shows chain `DIRECT`/node accordingly. (Observed.)
2. **LAN client → `stdn2.iau.ir`**: same intercept, but rule #1 pins **DIRECT** — mihomo itself dials out ccmni1. Verified `chain=DIRECT` in `/connections`. Same for `*.srbiau.ac.ir`, any `*amoozesh*`.
3. **Any UDP :443 (QUIC)** from br0: dropped in mangle `X28_NOQUIC` → client falls back to TCP → captured by flow 1/2. (Rule present; fallback INFERRED from standard browser behavior.)
4. **Router-local traffic** (curl, bot, ntpd): OUTPUT is not redirected → egress ccmni1 directly; bot explicitly dials `socks5h://192.168.70.1:1080` to force the tunnel for Telegram/Samantel.
5. **LAN → VPS panel `185.137.27.122`**: `RETURN`ed by `X28_SPLIT`, forwarded plain (also a DIRECT rule inside mihomo as belt-and-braces).
6. **Tunnel death**: probe fails ×2 → dns-fix flips dnsmasq to ISP servers **and** inserts top `RETURN` in `X28_SPLIT` (whole LAN goes direct = fail-open; IR sites fine, filtered sites dark) → auto-reverts when the probe passes again. In parallel: vps-heal fires panel `restartSb` after 4 min of dead auto-group, and — independently of the X28's own loop — the workstation watcher fires the same restart from its vantage at ~2 min (SSH-relay fallback if its direct leg is filtered).
7. **Operator loss**: 3 consecutive direct-probe failures (at 60 s cadence ≈3 min) → watchdog selects fallback PLMN (cmd 228), confirms data, re-applies dns-fix, notifies Telegram, records ledger pair; later probes preferred with exponential backoff and auto-returns.
8. **Wedged bearer** (IP present, no data, switches ineffective): after 2 failed switch rounds inside the cooldown-wait window the watchdog escalates to a **bearer bounce** — forced re-registration on the current PLMN via cmd 228 (verified live: data restored in ~19 s); ledgered + notified; dry-run env honored.
9. **Power cut / reboot**: full stack rebuilds from rc.local + S95–S99 services + net-hotplug; ~90 s in, the Boot Doctor runs the health gate, repairs known races and sends one verdict card. **Verified by controlled reboot 2026-08-22**: SSH back in ~70 s, all 10 custom services running, iptables chains rebuilt, DNS tunnel mode restored, tunnel probe 204, HEALTH GREEN.

## 7. External Dependencies

| Dependency | Use | Endpoint | Auth material (location) | When unavailable |
|---|---|---|---|---|
| MCI 5G (Samantel SIM) | all WAN | APN `du`, PLMN 424/03 | SIM | watchdog → Rightel; fail-open DNS |
| VPS sing-box/s-ui | tunnel exit + self-heal target | `85.121.124.158` :443/:2095/:31800 | Reality uuid/pk/sid in mihomo conf; `PANEL_*` in `/etc/sui-heal.conf` | fail-open mode; vps-heal tries restartSb |
| Telegram Bot API | control/alerts | api.telegram.org via :1080 | `TOKEN`/`CHAT_ID` in `/etc/tg.conf` | alerts/control silently lost (best-effort design) |
| Samantel PWA | balance/quota | `pwa.samantel.ir` | phone/pass in `/etc/samantel.conf`; cached Bearer 28 d | guarded cache serves last-good; budget shows honest no-data |
| Cloudflare DoH 8.8.8.8 | mihomo upstream (via `auto`) | DoH | none | DNS falls to ISP mode with the rest |
| StevenBlack hosts | ad-block source | raw URL (socks→direct) | none | previous list retained |
| NTP pools | clock (`ntpd -p cn.pool.ntp.org -p *.openwrt.pool…`) | udp/123 | none | **clock skew observed** (see §13) |

## 8. Persistence & Storage Map

- **Survives reboot:** everything under `/data` (proxy stack, configs, ledgers, telemetry, backups, `bot-state/offset`, `owners.conf`, `adblock/`), `/overlay` files (`/root/*.sh`, `/etc/*.conf` secrets), vendor NVRAM (SSID/LAN), rc.d symlinks, rc.local edits, iptables are **rebuilt** at boot by scripts.
- **Lost at reboot (by design):** `/tmp` — dnsmasq conf (regenerated by lan_mgr then fixed by dns-fix), leases, samantel token/packages cache, balance cache, bot pid/heartbeat, watchdog switch-stamps, budget cooldown stamps, mini_httpd confs.
- **Retention:** telemetry ≤5000 lines; watchdog.log ≤400; usage day-files 35 days (owners rollups kept forever); drift snapshots keep 14; adblock weekly; rollback snapshots in repo `router/x28/backup/rollback-{20260820-2359,20260821-0028,20260822-0300,20260822-2230}` + device tarballs `/data/proxy/backup/*.tar.gz` (0600, contain real secrets). The `-2230` one (40 files incl. secrets + generated dnsmasq conf) is the restore point for the always-up batch.
- Growth watch: `/data` at 58 % (largest consumers: mihomo 70 M incl. geo data, legacy engines ~120 M combined, backups 25 M).

## 9. Current-State Inconsistencies

1. **Dual writers / mixed schemas in one telemetry file** — `x28-thermal-loop.sh` appends minute-grain `ts|temp=|load=|rsrp=` rows while `x28-telemetry.sh` appends hourly `ts|total_gb|balance_gb|proxy|op|rsrp|temp|load` rows to the same `/data/proxy/usage/telemetry.log` (both formats observed interleaved). Any single-schema parser sees drift.
2. **Device clock/timezone confusion — now guarded** — uci timezone is `<+0330>-3:30` but `/etc/TZ` contains `UTC-4`, and the wall clock has been observed hours off the workstation. ntpd targets `cn.pool.ntp.org`/openwrt pools which may be unreachable without the tunnel. The maintenance window now refuses to reboot when an HTTP-Date cross-check (fetched over the direct path) shows >±30 min skew, alerting once per day instead; Jalali/Friday logic still inherits the raw device clock.
3. **uci vs runtime divergence** — `network.lan.ipaddr='192.168.1.1'` while live br0 is `192.168.70.1` (lan_mgr/NVRAM wins); uci dhcp `start=100 limit=150 leasetime=12h` vs generated `.100–.200, 24h`; uci firewall `forward=REJECT` vs live ACCEPT-with-custom-chains. Consequence: any tooling that trusts uci (or a future fw3 reload) will fight reality.
4. **Repo/device script split** — rc.local and hotplug run the **device-only** `tproxy-fixed-enable.sh`; the repo’s `tproxy-enable.sh`/`stage2-*.sh` build different (older) chains and are not referenced at boot.
5. **Legacy engine remnants** — xray/xray.stock/sing-box trees (~120 MB) and a running v2raya (`:2017`) serve no traffic purpose today; they consume `/data` and add surface area.
6. **Balance history empty** — `/etc/balance-log/` does not exist because nothing schedules `balance.sh --daily`; consequently reports show “Drain: collecting data” and Budget’s days-axis relies on projections only.
7. **Dormant features awaiting inputs** — `wifi.conf` absent (`/wifi` sends the explanatory card; `qrencode` still not installed), `/etc/tunnel.conf` + cloudflared absent (stub loop spins), `owners.conf` maps both known devices to one person.
8. **babaii provider drift** — TCP :23993 is open again but the VLESS handshake fails identically with and without `flow: xtls-rprx-vision`: the provider rotated user/protocol facts we mirror in mihomo. Needs the babaii panel/subscription checked externally (ticket `needs-info`).
9. **Panel restartSb is vantage-sensitive** — from the X28 (or anything dialing via its local path) `POST /app/api/restartSb` answers JSON `success:true`; from the workstation the identical request (every header/HTTP-version/raw-socket variant tested) closes with rc=52 empty-reply, while login/status work fine. Workaround shipped: workstation watcher falls back to SSH-relaying the device one-shot heal.
10. **Controller alive-flag staleness** — right after an engine restart, `/proxies/<node>.alive` can read optimistic before the first url-test round completes; the per-node `/proxies/<n>/delay` endpoint is ground truth.
11. **Outage Ledger seeded by a drill** — first recorded pair (2026-08-22 22:17→22:20, 2 m12 s) came from the controlled dead-endpoint ladder exercise, not a real outage; totals include it until ages out of monthly scope.
12. **Month log zero-row** — `month/2026-08.log`’s first line totals zeros because `roll()` fired right after the midnight boundary before traffic accumulated (marker prevents a second write for that day).

## 10. Verification Reference

```bash
# --- from the workstation (WSL) ---
ssh -oHostKeyAlgorithms=+ssh-rsa -oPubkeyAuthentication=no root@192.168.70.1   # pw prompt

# --- on the X28 ---
ip addr; ip route; ip rule; ip route show table 17000; brctl show
iptables-save -t nat; iptables-save -t mangle | grep X28_NOQUIC -A2; iptables-save -t filter
netstat -lntup                     # expect mihomo 1080/12345/5353/9090, dnsmasq :53,
                                   # dropbear :22, telnetd :23, mini_httpd :80/:443, v2raya :2017
grep -E 'server=|no-resolv|conf-file' /tmp/dnsmasq.conf     # tunnel mode => 127.0.0.1#5353 + no-resolv
sh /data/proxy/dns-fix.sh                                   # prints: dns-fix: mode=tunnel|isp (dnsmasq restarted|no change)
/data/proxy/mihomo/mihomo -v
curl -s 127.0.0.1:9090/rules | /data/proxy/jq -r '.rules[:6][].type+" "+.payload+" -> "+.proxy'
curl -s http://127.0.0.1:9090/connections | /data/proxy/jq -r '.connections[]|.metadata.host+" "+(.chains|join(","))'
sh /data/proxy/x28-health.sh                                # expect final line: HEALTH: GREEN
pgrep -f 'x28-bot.sh supervise|mihomo|operator-watchdog|usage-collect|adblock-loop|x28-vps-heal|x28-thermal-loop|x28-maint|x28-drift'
ls /etc/rc.d/ | grep x28                                    # boot order sanity
tail -3 /data/proxy/watchdog.log; tail -2 /data/proxy/usage/telemetry.log
cat /tmp/dnsmasq.leases

# always-up batch specifics
tail -1 /data/proxy/watchdog.log                            # expect: interval=60s threshold=3 bounce_after=2
sh /data/proxy/x28-maint.sh once                            # prints dow/hr/uptime/free/week -> decision
sh /data/proxy/x28-drift.sh status                          # tracked count, pending?, last-run
WATCHDOG_WAN_BOUNCE_DRYRUN=1 sh /data/proxy/operator-watchdog.sh bounce   # logs DRYRUN line only
for n in vps-reality hy2 cdn-ws babaii; do curl -s -m 10 "http://127.0.0.1:9090/proxies/$n/delay?url=https%3A%2F%2Fwww.gstatic.com%2Fgenerate_204&timeout=8000"; echo; done
BOOT_DELAY=1 sh /data/proxy/x28-boot-doctor.sh run          # one-shot verifier (sends verdict card)
cat /data/proxy/outage-ledger.log                           # epoch|down/up pairs

# --- from a LAN client ---
curl -skI https://stdn2.iau.ir                              # should answer via DIRECT path
# then on X28: connections table must show host stdn2.iau.ir chain=DIRECT
```

Expected deviations: `mode=isp` + top `RETURN` in `X28_SPLIT` ⇒ tunnel currently down/fail-open; missing mihomo listeners ⇒ engine crashed (check `logread`/procd); extra `server=` lines in dnsmasq conf ⇒ dns-fix hasn’t run after a lan_mgr regeneration (run it manually).

## 11. As-Built Configuration Reference (secrets redacted)

| File (device) | Mode | Contents (shape only) |
|---|---|---|
| `/data/proxy/mihomo/config.yaml` | 600 | full engine config; secrets: vless uuid/pk/short-id, hy2 passwords — **redacted**; backup `config.yaml.bak-20260822-0425` beside it |
| `/etc/tg.conf` | 600 | `TOKEN=<redacted>` `CHAT_ID=<redacted>` |
| `/etc/samantel.conf` | 600 | `SAMANTEL_PHONE/PASS`, `BALANCE_WARN_GB/URGENT_GB/WARN_DAYS/URGENT_DAYS`, `BALANCE_RATE_ALERT_GBH`, `MONITOR_REFRESH_MIN` |
| `/etc/sui-heal.conf` | 600 | `PANEL_HOST=85.121.124.158 PANEL_PORT=2095 PANEL_USER=<redacted> PANEL_PASS=<redacted>` |
| `/data/proxy/owners.conf` | 600 | `mac|parsa` ×2 |
| `/tmp/dnsmasq.conf` | generated | see §5.5; regenerated by lan_mgr, repaired by dns-fix |
| `/data/proxy/adblock/adblock.conf` | 644 | ~93 k `address=/domain/` denies |
| `/data/proxy/bot-state/offset` | — | last processed Telegram update_id +1 |
| repo mirror | — | `~/home-network/router/x28/**` (canonical copies; deploy via `deploy.sh`, needs env `X28_PASS`, `AX3T_PASS`, optional `X28_PROXY_CONFIG`; uses `ssh 'cat > path'` — dropbear has no sftp) |

*End of as-built specification.*

---

## Addendum (rev 3): Rescue pool subsystem (x28-rescue-pool)

New components since rev 2:
- `/data/proxy/rescue/{channels.txt,raw/collected.txt,rescue.log,last-fetch,enabled,state}` — collector cache + supervisor state.
- `/data/proxy/rescue-collect.sh` — tunnel-gated 6-hourly Telegram scraper (147 vendored channels), sweep deadline 300 s, merge/dedupe/cap 300.
- `/data/proxy/rescue-convert.sh` + `rescue-vmess.jq` — all-8 protocol URI→provider converter (allowlist grammars, caps, pure-awk base64).
- `/data/proxy/x28-rescue.sh` (+ init S97) — admission loop (convert → atomic swap → PUT hot-reload of `rescue-pool`) and world supervisor (hysteresis promote 4 / demote 10, cards, `/rescue` switch persisted at `enabled`).
- Engine config now carries `proxy-providers.rescue-pool` (path must be under engine home per SAFE_PATHS), groups `rescue` + `world [auto,rescue]`, and `MATCH,world`. World pinned to `auto`; supervisor flips via `PUT /proxies/world`.
- Live evidence: first real sweep collected 300 URIs; converter admitted 46 candidates; supervisor correctly holds while all candidates dead.

Verification:
```sh
sh /data/proxy/rescue-collect.sh status
sh /data/proxy/rescue-convert.sh            # converts raw cache
sh /data/proxy/x28-rescue.sh status         # enabled/world/pool/raw line
WATCHDOG_WAN_BOUNCE_DRYRUN=1 sh /data/proxy/operator-watchdog.sh bounce   # unrelated sanity
```

### Rev 3 addendum — implementation findings & complete state (2026-08-23)

**Boot-order integration:** `S97x28-rescue` sits with the other S97 loops; shutdown K-link present. Full custom chain is now: S95 thermal/usage → S96 bot/telemetry/vps-heal → S97 adblock/tunnel/**maint**/**drift**/**rescue** → S98 proxy → S99 v2raya/vnstat/watchdog/**boot-doctor**.

**Rescue subsystem storage (all persistent under /data unless noted):**

| Path | Purpose | Retention |
|---|---|---|
| `/data/proxy/rescue/channels.txt` | vendored Telegram channel list (147) | static, owner-editable |
| `/data/proxy/rescue/raw/collected.txt` | merged URI cache (deduped, cap 300) | rolling union |
| `/data/proxy/rescue/{last-fetch,last-run?}` | age-gate stamps (epoch) | overwritten per run |
| `/data/proxy/rescue/enabled` | persisted master switch (`1`/`0`) | survives reboot |
| `/data/proxy/rescue/state` | supervisor streaks (`dead_streak alive_streak`) | overwritten each tick |
| `/data/proxy/rescue/{collect.log,rescue.log}` | sweep summaries / transitions+reloads | append-only |
| `/data/proxy/mihomo/rescue-pool.yaml` | **live provider payload** (single-line JSON `{"proxies":[…]}`) | swapped atomically on change |
| `/data/proxy/mihomo/config.yaml.bak-rescue-*` | pre-landing config backup | one-off |

Scripts: `rescue-collect.sh`, `rescue-convert.sh` + `rescue-vmess.jq`, `x28-rescue.sh` (+ init S97). Bot gains `/rescue [on|off]`; Weekly Digest gains a `rescue:` line.

**Implementation findings (device/busybox/engine facts worth remembering):**

1. **BusyBox awk (1.30) gaps hit in practice:** no `nextfile` ("call to undefined function"), no `switch`, no `strtonum`, cannot assign an array to a scalar, and a ternary branch containing a user-function call misparses as "call to undefined function" at that line. All worked around in `rescue-convert.sh` (pure-awk base64 decoder with padding normalization, flattened ternary, hex lookup table).
2. **Base64 padding bug class:** skipping byte-emission on `=` via `continue` silently drops the final 1–2 plaintext bytes — found by fixtures (`test1234` → `test12`), fixed by falling through with zero-valued sextet.
3. **mihomo SAFE_PATHS:** provider `path:` must live under the engine home dir — `/data/proxy/rescue/nodes.yaml` was rejected; payload moved to `/data/proxy/mihomo/rescue-pool.yaml`.
4. **Provider payload as JSON works:** mihomo's YAML reader accepts the single-line `{"proxies":[…]}` document; kept because jq emits it safely from untrusted strings.
5. **Hot reload seam:** `PUT /providers/proxies/rescue-pool` re-reads the file immediately; atomic swap + change-detection avoids needless reloads.
6. **Controller `alive` staleness:** right after restart, group member flags read optimistic — per-node `/proxies/<n>/delay` is ground truth (bit twice during landing).
7. **Panel `restartSb` vantage quirk:** device-origin POST answers JSON; workstation-origin POST closes rc=52 regardless of headers/HTTP version/raw sockets — hence the SSH-relay fallback in `sb-selfheal.sh`.
8. **Sweep yield variability:** a full 147-channel sweep can return 0 URIs when channels are between config drops (first 5-channel probe yielded nothing while the later full sweep hit the 300 cap). Sweep deadline (300 s) + unconditional summary log keep runs bounded and observable.
9. **First admission:** 300 raw URIs → **46 candidates** admitted into the engine (rest failed allowlist/dedupe); all 46 dead at first health round → supervisor correctly HOLDS (promote requires ≥1 alive rescue node). Pool refreshes every 6 h; promotion arms automatically when any candidate breathes.
10. **Converter default-input bug class:** early version ignored its `RESCUE_RAW` fallback when invoked without args (tests caught wholesale empties).

**Extra verification commands:**

```sh
sh /data/proxy/x28-rescue.sh decide                 # current decision inputs
DRYRUN=1 HEALTH_AUTO_CMD='echo 0' sh /data/proxy/x28-rescue.sh tick   # would-promote drill
/data/proxy/jq -r '.proxies[0:5][]|.type+" "+.server' /data/proxy/mihomo/rescue-pool.yaml
curl -s http://127.0.0.1:9090/providers/proxies/rescue-pool | jq -r '.proxies|length'
```

### Rev 3 addendum — Telegram bot presentation & reliability overhaul

`x28-bot.sh` now renders every card in **Telegram HTML** (verified against Bot API 10.2): bold emoji titles, italic freshness meta, `<pre>` aligned tables, `<blockquote expandable>` for raw dumps, status-verdict emoji mapped from the health gate. Transport is centralized in `tg_post` with response-aware logging (`error_code`/`description` → `hb.log`); `split_chunks` enforces the 4096-char API budget at newline boundaries; failed panel edits fall back to fresh messages so data always lands.

Reliability hardening landed in the same pass: instance lock via atomic `mkdir`; heartbeat keeper self-exits when its parent dies (orphaned keepers could fake liveness forever); callback taps are acked immediately, staleness-guarded via embedded message date, and dispatched after ack; getUpdates offset persists *after* handling with the 600 s staleness filter absorbing replays; user args validated through `safe_arg`; poll errors classified (409 conflict / 401 token / transient); jq absence degrades loudly instead of zombie-looping. Tests source the bot in `lib` mode (no config needed): 18 format asserts, 14 reliability regressions, 19 panel asserts.

### Rev 3 addendum — Owner Panel & Ledger (x28-owner-ledger)

New stores: `usage/owners-d/YYYY-MM-DD` (`person|mac|up|down` — device-granularity rollups written by the nightly roll), `usage/ledger/J-<month>.txt` (immutable frozen pages). New scripts: `x28-owner-backfill.sh` (idempotent one-shot converter), upgraded `x28-owners.sh` (hostname-aware assign, rename subcommand), rewritten `x28-people.sh` (dual-mode: HTML ledger card with share bars / plain text for alerts).

Bot: `/owner` opens an inline-keyboard Owner Panel (unassigned devices as tappable buttons, person rows with counts, utility row); callbacks `own:*` staleness-guarded and acked; `/ledger` lists frozen pages as buttons; `/people`/`/month` render the Persian-first HTML Ledger.

Live: 3 days / 13 rows backfilled from real cache; مرداد ledger renders with parsa 2.0 GB (100% bar) + unassigned breakdown; health gate GREEN.
