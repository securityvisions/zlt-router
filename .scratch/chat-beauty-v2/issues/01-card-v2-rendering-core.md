# 01 — Card v2 rendering core + Status demo

**What to build:** The shared rendering primitives every other ticket composes: a progress-bar generator (`bar`), a balance/usage-trend sparkline generator (`spark`), a column-padding helper, and the v2 Card anatomy (title, section rule, monospace aligned columns, tier badge, footer). The first live consumer is the Status Card — uptime, load, RAM, temperature, and storage — with a gauge bar for storage and aligned value columns. This ticket stands alone so the foundation is demoable before the remaining tickets lean on it.

**Blocked by:** None — can start immediately

**Status:** resolved

## Answer

Rendering core landed in `botcmd.sh`: `pad` (column align), `bar` (10-wide ▰/▱ gauge, any percent with width override), `spark` (8-level ▁▂▃▄▅▆▇█ trend from `|`-separated series, lookup-array indexed so it's locale-safe under BusyBox awk), `temp_badge` (🟢<60 · 🟠<75 · 🔴). Status card rewritten: aligned columns, storage gauge, temp badge — and fixed a pre-existing units bug (BusyBox `free` ignores `-m`; RAM now computed as MB from KB). Verified on the router: syntax OK, helpers render correctly (bar 0/59/100, spark `146|146|120|100|88` → `██▅▂▁`, single → `▄`, empty → empty), deployed and running. Demo: `/status` in Telegram.

- [x] The rendering helpers exist and produce correct output for the full 0–100% range, empty input, and single-value input
- [x] The sparkline helper renders the last-N values from a `|`-separated series as 8-level blocks (`▁▂▃▄▅▆▇█`), including sparse and one-point series
- [x] `/status` returns a v2 Card: title, section rule, aligned monospace columns, storage gauge, tier/temp badge
- [x] The Card renders in Telegram with no raw HTML leaking (no unescaped `& < >` in output)
- [x] The helpers work under the router's BusyBox ash (no bash-only constructs)

- [ ] The rendering helpers exist and produce correct output for the full 0–100% range, empty input, and single-value input
- [ ] The sparkline helper renders the last-N values from a `|`-separated series as 8-level blocks (`▁▂▃▄▅▆▇█`), including sparse and one-point series
- [ ] `/status` returns a v2 Card: title, section rule, aligned monospace columns, storage gauge, tier/temp badge
- [ ] The Card renders in Telegram with no raw HTML leaking (no unescaped `& < >` in output)
- [ ] The helpers work under the router's BusyBox ash (no bash-only constructs)

## Comments

Rendering mapping: `bar` = 10 blocks of `▰`/`▱` by percentage; `spark` maps the series min..max onto `▁▂▃▄▅▆▇█` (8 levels).