# 02 — Boot doctor (post-boot convergence verify + repair)

**What to build:** After a power cut or reboot, recovery currently *assumes* the boot chain worked (rc.local rebuilt rules, DNS mode re-picked, services respawned). This ticket adds a one-shot **boot doctor**: ~90 s after boot it runs the health gate and, if anything is RED, repairs the known boot races automatically — re-applies the transparent-proxy rules and DNS mode, restarts the proxy engine and bot — then sends one Telegram verdict card ("boot verified GREEN" or "repaired: <what>"). Reboots become self-verifying instead of assumed.

**Blocked by:** None — can start immediately.

**Status:** resolved (reboot exercise at batch end)

- [ ] One-shot verifier runs once per boot (~90 s delay), never loops; safe under procd
- [ ] RED verdict triggers repair actions in order: transparent-proxy rules → DNS mode → proxy engine restart → bot restart; each step logged
- [ ] Single Telegram card reports final state (verified vs repaired-vs-failed) with what was done
- [ ] All-GREEN boots produce the quiet "verified" card only (no spam on healthy boots)
- [ ] Decision logic (given health-gate output → repair plan) is pure and unit-tested with fixture health outputs
- [ ] Wired into the boot sequence after the custom service set; deployed with health gate GREEN before/after; live reboot exercise produces exactly one correct verdict card
