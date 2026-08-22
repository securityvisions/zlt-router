# 06 — Bot `/rescue` command (persisted switch)

**What to build:** `/rescue` → status Card (world, owned aliveness, rescue pool size/aliveness, enabled flag). `/rescue on|off` flips the persisted master switch (off freezes admission + forces world back to auto). Unknown args answered with usage.

**Blocked by:** 05.

**Status:** ready-for-agent

- [ ] Status/on/off wired to the persisted flag; survives reboot
- [ ] off forces world→auto immediately even while promoted
- [ ] Bot-panel grep assertions updated (house style)
