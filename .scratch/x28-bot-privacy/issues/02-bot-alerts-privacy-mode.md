# 02 — Bot + alerts privacy mode

**What to build:** A `/privacy` bot command toggles privacy mode on/off. When on, every card the bot sends (owner panel, /devices, /digest, people report) and every alert/digest sent through the alerts path is scrubbed at the send funnel — so a recorded demo shows no real names, MACs, IPs, or hostnames — while tap-to-assign still works because only display text is masked, never callback data.

**Blocked by:** 01 — Privacy scrub module (needs the scrub function + toggle).

**Status:** resolved

- [x] Bot command `/privacy` toggles the state and replies a clear on/off confirmation
- [x] Bot send path (all cards + panel edits) applies the scrub when privacy is on
- [x] Alerts path (digest, monthly people report, alerts) applies the scrub when on
- [x] Interactive panels keep working while masked (callback data untouched)
- [x] Live verification: privacy on → real cards masked on the phone