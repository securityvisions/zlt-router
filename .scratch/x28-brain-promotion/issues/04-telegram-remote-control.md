# 04 — Telegram remote control

**What to build:** Remote control of the network from anywhere via the
Telegram bot: commands for status, link details, and operator switching
(MCI / Rightel), plus help — answered with the same card formatting as
the alerts. The bot runs as a supervised long-poll service (procd
respawn + stale-heartbeat detection, the model the previous interactive
bot used), accepts commands only from the allowlisted chat, and performs
operator switches **only** through the proven operator re-select path —
never the PLMN-lock command that previously broke this modem's boot.

**Blocked by:** 03 — Status collector + Telegram alerts.

**Status:** resolved (all ACs proven live. Kill test: respawn in 5s. Wedge
test (SIGSTOP): culled at 200s stale, replaced. User round-trip: `/status`
processed at 11:22:55 through the restored mihomo tunnel. Incident
hardening folded in: atomic heartbeat write + empty-read guard, persistent
command offset in /data, stale-update filter — proven in production when it
skipped a 6826s-old replayed update after the tunnel returned.)

**Incident note (2026-08-21 01:00):** the user's live /switch_rightel test
succeeded (Rightel, data confirmed) but coincided with the VPS sing-box
core hanging — killing tunnel DNS/proxy house-wide until the panel restart,
and a vendor WiFi-driver firmware reload that wedged both radios until an
X28 reboot. Learnings: operator switches can restart the vendor network
stack; dns-fix auto-selects tunnel vs ISP fallback DNS per VPS health
(ticket 10); the bot never replays stale commands.

- [x] `/status`, `/link`, `/switch_mci`, `/switch_rightel`, `/help`
      answered with cards within seconds.
- [x] Commands from any other chat are ignored (auth by chat allowlist).
- [x] A live test switches to each operator via Telegram and confirms
      data works after each switch. (/switch_rightel by user, data
      confirmed by watchdog; switch-back via the same one-shot path.)
- [x] The bot survives being killed (procd respawn) and a wedged state
      (stale heartbeat → restart), demonstrated by killing the process.
- [x] The health gate is green after deployment; no PLMN-lock command
      appears anywhere in the deployed code.
