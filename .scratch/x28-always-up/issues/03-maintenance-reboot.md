# 03 — Maintenance auto-reboot window

**What to build:** Slow leaks (vendor daemons, engine memory growth) eventually wedge the VPN even though every individual service looks alive. This ticket adds a maintenance window: every night the router checks whether it qualifies — uptime beyond 14 days **or** free RAM under 60 MB — and on the next Sunday 05:00 that finds a qualifier, sends a warning card and reboots. The house sleeps through it; the VPN comes back fresh via the existing boot chain (plus the boot doctor once landed).

**Blocked by:** None — can start immediately (coordinates with 02 but does not gate on it).

**Status:** resolved

- [ ] Qualification decision is a pure function (dow, hour, uptime-days, free-MB → reboot yes/no), unit-tested at boundaries: exactly 14 days, exactly 60 MB, wrong weekday, wrong hour
- [ ] Loop runs from a procd service (no cron); checks nightly, acts only in the Sunday 05:00 window
- [ ] Warning card sent immediately before reboot; reboot proceeds even if Telegram is unreachable
- [ ] A state marker prevents double-reboot within the same window (power blip during reboot cannot loop)
- [ ] Dry-run env prints the decision without acting; deployed with health gate GREEN; live dry-run shows correct qualify/disqualify for current uptime/RAM

## Comments

Shipped: hnlib decisions (19 maint + 4 httpdate tests), x28-maint.sh procd loop with clock-skew guard (HTTP Date over direct path — addresses the observed device clock skew from AS_BUILT §13), warning card, ISO-week marker. Live once-mode verified (dow=6 → wait). Real in-window firing is inherently observable next Sunday 05:00.
