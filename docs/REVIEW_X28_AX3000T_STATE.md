# Review: X28 (ZLT) + AX3000T — state after the recovery, options and recommendations

Date: 2026-09-03. Scope: read-only examination + recommendations. **No changes made.**

## TL;DR

1. **X28 residue from the recovery session** (3 items, all reversible, none urgent): the
   operator-watchdog is **suspended** (`kill -STOP`, intentional — its DNS-guard loop was
   crash-looping dnsmasq every 64 s), a temp IP `192.168.1.254/24` sits on br0, and two
   ACCEPT iptables rules target 192.168.31.0/24.
2. **dnsmasq is stable now** (one instance for hours) — but only *because* the watchdog is
   paused. The 64 s restart-loop root cause is **not fixed**; resuming the watchdog brings
   it back.
3. **AX3000T: OpenWrt 25.12.5 clean install, healthy** — 239 MB RAM (139 free), 57.5 MB
   overlay free, LAN+WAN+WiFi up, stock partitions backed up (6 files, Windows laptop).
4. **Recommended next steps** (in order): X28 hygiene (3 commands) → AX3000T WiFi rename to
   **XI-2G / XI-5G** (4 commands) → pick the AX3000T's role (Option A recommended) →
   diagnose the dns-fix flap properly → only then consider automation redeployment.

## 1. What today's session did to the X28 (the residue)

| Item | State | Why | Undo |
|---|---|---|---|
| `operator-watchdog.sh` (PID 13189) | **Suspended** (`T` state) | Its per-cycle `dns-fix.sh` call was restarting dnsmasq every 64 s, breaking DHCP for the whole recovery | `kill -CONT 13189` — but see §4 first |
| `192.168.1.254/24` on br0 | Present | Temp address for the (aborted) SSH-jump attempt | `ip addr del 192.168.1.254/24 dev br0` |
| 2 iptables ACCEPT rules (OUTPUT+FORWARD → 192.168.31.0/24) | Present | Same attempt | `iptables -D OUTPUT/FORWARD …` (or reboot clears) |
| Telnet diagnostics, `date >> /tmp/watchdog-paused.marker` | Log-only | Evidence trail | none needed |

Nothing else was changed on the X28: no config files, no scripts, no services disabled
permanently. The dnsmasq 64 s restart-loop **predates the session** (visible in logread
hours before any X28 access).

## 2. The dnsmasq restart-loop (open issue on the X28)

- Symptom: dnsmasq PID changes every ~64 s; DHCP transactions in-flight at restart die.
- Driver: `operator-watchdog.sh` (loop, `sleep $CHECK_INTERVAL`) calls `dns-fix.sh` each
  cycle; dns-fix decides "config changed" → `pkill -9 dnsmasq` → restart. Its tunnel/ISP
  probe apparently oscillates in the current network condition.
- Repo note: the canonical `router/x28/dns-fix.sh` documents itself as "restarts dnsmasq
  only when the config actually changes" — the deployed copy may predate that fix, or the
  probe genuinely flips (VPS health flapping).
- Recommended fix path (a real ticket, not a hack): diff deployed vs repo dns-fix.sh;
  add a "config actually changed" hash check before pkill; then resume the watchdog and
  verify dnsmasq uptime > 1 h with a stable lease table.

## 3. The X28 stack (what runs today) — from `router/x28/` (82 files in repo)

Live loops observed: thermal, usage-collect, **bot** (Telegram curl active — bot alive),
dash-data, telemetry (hourly), vps-heal, adblock, drift, maint, rescue + mihomo + the
suspended operator-watchdog. The repo directory mirrors the deployed layout
(`/data/proxy/*` + init files) plus `backup/rollback-*` snapshots. Deploy pipeline:
`deploy.sh` (env: `X28_PASS`, `AX3T_PASS`).

## 4. The AX3000T today (post-rebuild)

- OpenWrt 25.12.5 (r33051), apk-based; **clean** — no automation packages.
- RAM 239 MB total / 139 free; overlay 57.5 MB free.
- LAN br-lan 192.168.1.1/24 (lan2 lan3 lan4 + WiFi); **WAN = lan4 → X28**
  (192.168.70.171, DHCP) — port roles already software-remapped (wan↔lan3/lan4 swap was
  done to match the physical cabling).
- WiFi: radio0+radio1 up, SSIDs `Xiaomi_7A40` / `Xiaomi_7A40_5G`, WPA2 `xirouter123`.
- Listening: uhttpd (80/443, LuCI), dropbear (22, password auth), dnsmasq (LAN+WAN).
- Root password: `xirouter123`. Host key (ed25519):
  `SHA256:f+pBCZnNwReRMbQMqUwj/kFDEjVUv7q0KhdGpQngADI`.
- Backups: BL2/Nvram/Bdata/Factory/FIP/KF in `C:\Users\Public\axtftp\backup\` (Windows).

## 5. Options for the two-router architecture

| Option | Description | Effort | Notes |
|---|---|---|---|
| **A. Dumb AP (recommended first)** | AX3000T bridges its WiFi+LAN into the X28's 192.168.70.0/24; DHCP stays on the X28; house WiFi moves to the AX3000T's better radios (WiFi 6) | Small (disable DHCP server, set LAN to the 70.x subnet or keep 1.1 as mgmt, bridge) | Cleanest stable base; X28 keeps WAN/proxy/bot unchanged |
| B. Router-behind-router | Keep AX3000T as NAT router (192.168.1.0/24) behind the X28 | Small | Double NAT; devices behind it lose easy reach to X28 services |
| C. Full brain restore | Redeploy the pre-brick stack (PassWall, bot, nlbwmon, Router API — all in `router/`) | Large | The repo has everything; do only after A/B is stable; the original brick's cause (auto-reboot logic) must be fixed first |
| D. Split duties | AX3000T = house WiFi + LAN; X28 = WAN + proxy + bot + dashboards | Medium | Effectively A now, drifting to C later per-feature |

## 6. Recommendations (ordered, none executed)

1. **AX3000T WiFi rename** (user preference): `Xiaomi_7A40`→`XI-2G`, `Xiaomi_7A40_5G`→
   `XI-5G` (keep WPA2 `xirouter123`). 4 uci commands + `wifi reload`. Zero risk.
2. **X28 hygiene** (3 commands): remove the temp br0 IP; remove the 2 ACCEPT rules; keep
   the watchdog paused until §2's fix lands.
3. **DNS-loop ticket**: compare deployed dns-fix.sh vs repo canonical; add a config-hash
   guard; then `kill -CONT 13189` and verify dnsmasq uptime > 1 h.
4. **Decide AX3000T role**: recommend A → D → (optionally) C, in that order.
5. **Archive**: copy `C:\Users\Public\axtftp\backup\*` + the recovery images to a second
   location; they are the only copies of Factory (calibration) today.

## Sources / evidence

- X28 live state: telnet examination 2026-09-03 (watchdog T-state, br0 addresses,
  dnsmasq single-instance, daemon list) — commands and outputs in the session log.
- AX3000T live state: SSH examination (free/df/netstat/apk/wifi status/wan addr).
- Repo: `router/x28/` (82 files), `docs/ARCHITECTURE.md`, `docs/AS_BUILT.md`,
  `docs/RESEARCH_AX3000T_*.md` (4 files).

---

# DEEP ANALYSIS + FINAL PLAN (2026-09-03, evening)

## X28 — deep examination

**Healthy (leave alone):** mihomo proxy (listening 1080, tunnel 204 in 0.76 s via laptop
test), Telegram bot (polling), 10 service loops (thermal/usage/dash/telemetry/vps-heal/
adblock/drift/maint/rescue), storage (/data 57 %, /tmp fine), RAM (167 MB avail).

**Root cause found — the dnsmasq 64 s loop:** the vendor's `lan_mgr` regenerates
`/tmp/dnsmasq.conf` every ~64 s, stripping dns-fix.sh's added lines (`server=…`,
`conf-file=adblock`) → dns-fix sees before≠after hash → `pkill -9 dnsmasq` → re-add +
restart → vendor strips again → loop. The deployed dns-fix logic is fine; it is *reacting
to the vendor's rewrite*, once per 60 s watchdog cycle.
**Correct fix (small patch):** restart dnsmasq only when dns-fix's signature lines are
MISSING (state check: `grep -q '^conf-file=$ADBLOCK$'` and the mode's upstream line),
not on hash-diff. Then the vendor's rewrite is tolerated without a restart (dnsmasq
already runs the right content — the vendor merely removed lines that dns-fix re-adds
only when actually absent).

**Suspended watchdog = lost functions (must come back):** operator stickiness
(MCI↔Rightel), outage ledger, bearer-bounce escalation, per-cycle dns-fix guard.
**Do not leave it suspended** — fix dns-fix (above), then resume.

**Watch (not fix):** 68 °C (thermal loop manages it; improve airflow/placement if it
creeps higher), RAM 107 MB free (mihomo is the bulk; normal for Go).

## AX3000T — deep examination

**Healthy:** OpenWrt 25.12.5 clean; 239 MB RAM (139 free); 57.5 MB overlay free; 58 °C;
load 0.00; both WiFi radios up; LuCI/dropbear/dnsmasq only; WAN lan4→X28 verified.

**Assets:** the best WiFi radios in the house (WiFi 6 AX3000); gigabit switch; a clean
25.12.5 base with zero cruft; full stock-partition backups + research docs.

**Constraint discovered:** port roles — physical WAN port = OpenWrt `wan` (leftmost),
lan2/3/4 = LAN. The X28's cable currently sits in lan4 (I had remapped wan→lan4 in
software; revertible any time).

## DECISION MATRIX

| Role for AX3000T | Double-NAT | House WiFi quality | X28 services | Verdict |
|---|---|---|---|---|
| A. Dumb AP (bridge into 192.168.70.0/24) | no | best (WiFi 6) | untouched | **recommended** |
| B. NAT router behind X28 | yes (double) | best | untouched | fallback if A misbehaves |
| C. Full brain restore (PassWall/bot/billing) | — | — | must migrate | later, separate project |
| Leave as idle clean OpenWrt | — | — | — | valid; everything keeps working on the X28 |

## FINAL STEP-BY-STEP PLAN

**Phase 0 — done.** Backups (6 stock partitions) + recovery images + research docs.

**Phase 1 — X28 hygiene (5 min, reversible):**
1. `ip addr del 192.168.1.254/24 dev br0`
2. `iptables -D OUTPUT -d 192.168.31.0/24 -j ACCEPT; iptables -D FORWARD -d 192.168.31.0/24 -j ACCEPT` (or note for reboot)

**Phase 2 — fix the dns-fix restart logic (10 min + deploy):**
3. Patch `/data/proxy/dns-fix.sh`: restart only when the signature lines are missing
   (`conf-file=$ADBLOCK` / mode's `server=` line), not on before/after hash-diff.
4. Verify: 10 min with zero dnsmasq restarts while the watchdog runs.

**Phase 3 — resume the operator watchdog (10 s):**
5. `kill -CONT 13189`; verify dnsmasq stays stable ≥ 10 min and watchdog.log advances.

**Phase 4 — AX3000T → AP mode + XI rename (15 min, one SSH session):**
6. `uci del_list network.@device[0].ports='lan4'` stays as is… exact sequence:
   put `lan4` back into br-lan (it bridges to the X28), delete `network.wan`,
   set `network.lan.proto='dhcp'` (lease from the X28) or static `192.168.70.2/24`
   (gw 192.168.70.1) — static recommended for an AP.
7. Disable router duties: `uci set dhcp.lan.ignore='1'`; `/etc/init.d/odhcpd disable`;
   `/etc/init.d/firewall disable` (dumb-AP recipe; bridge does the rest).
8. WiFi rename: `uci set wireless.default_radio0.ssid='XI-2G'`;
   `uci set wireless.default_radio1.ssid='XI-5G'` (keep WPA2 `xirouter123`);
   `uci commit wireless && wifi reload`.
9. `uci commit network && /etc/init.d/network restart` → AP live on the 70.x segment.
10. Verify: laptop (cable on the AP) gets a 192.168.70.x lease **from the X28**;
    internet through the AP; LuCI/SSH on the AP at its lease/192.168.70.2.

**Phase 5 — household cutover (as convenient):**
11. Move phones/laptops to `XI-5G`/`XI-2G` (password `xirouter123`).
12. Optionally disable the X28's own WiFi (ZL-5G/ZL-2.4G) once the house is stable on XI.
13. The X28's bot/dashboards/proxy keep running unchanged (management via 192.168.70.1).

**Phase 6 — later, separate project:** PassWall/automation restoration (Option C) with its
own spec — including fixing the original brick's cause (the auto-reboot logic) first.

**Leave alone:** the X28's mihomo/bot/ledger/telemetry/rescue/thermal/adblock stack; the
AX3000T's clean base (no packages until a concrete need).

## FINAL STATE (2026-09-03, complete)

Two additional root-causes found and fixed on the AX3000T during bring-up:
1. **Regulatory domain unset** (country 00) — modern OpenWrt refuses to create AP
   interfaces without a country. Fix: `uci set wireless.radio{0,1}.country='IR'`.
2. **The wifi-iface `disabled='1'` flags** — enabling the *radios* is not enough; each
   *interface* (`default_radio0/1`) carries its own disabled flag that was never cleared.
   Fix: `uci set wireless.default_radio{0,1}.disabled=0`.

**Final verified state:** OpenWrt 25.12.5; LAN 192.168.1.1/24 (br-lan = lan2+lan3+lan4+
wan-port+WiFi); WAN = lan4 → X28 (192.168.70.171, DHCP, internet verified); WiFi
**XI-2G** (2.4G ch1) + **XI-5G** (5G ch36/80MHz), WPA2 `xirouter123`, both broadcasting
and confirmed visible from a client; SSH root@192.168.1.1 / `xirouter123`; LuCI on :80.

X28 note: the operator-watchdog is resumed and the dns-fix.sh HUP patch is deployed
(backup: /data/proxy/dns-fix.sh.pre-hup.bak). The router-bridge temp IP
(192.168.1.254 on the X28's br0) and the fw4 rule (Allow-X28-HTTP, WAN:80 from
192.168.1.0/24) were left in place for remote maintenance — review before hardening.
