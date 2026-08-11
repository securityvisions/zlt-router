# 02 — Dashboard + floating tab bar + shared components

**What to build:** the Dashboard screen is the first fully-polished surface: a dark-gradient HeroPanel showing the data balance gauge + proxy status + device count + today's usage + disk + load/temp, a 2×3 tile grid below using the new Panel component, and a floating-island bottom tab bar with 5 hand-drawn Canvas network icons (grid, chart-line, lightning, sliders, gear). The shared component library is created here: Panel, Band+bandShape, SectionHead, RowTitle, RowAmount, DetailRow, Gauge (arc with green/amber/red zones + ModamFigures label + animated fill), StatusPill (colored pill for proxy UP/DOWN), and the back-navigation scaffold (top bar with back arrow on non-top-level screens). The SetupScreen and LockScreen are also restyled with the new tokens.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] `TabBar.kt` created: floating-island nav (Radius.group=28dp, 12dp shadow, Space.m from edges), 5 Canvas-drawn network glyphs (2dp pen, Round cap/join, 18dp safe area in 24dp canvas), gold indicator under active tab, badge dot support
- [ ] Shared components created: Panel (surfaceVariant bg, Radius.card, Space.l padding), Band+bandShape (flush row clip logic), SectionHead (headlineMedium, asymmetric padding), RowTitle (Modam, TextAutoSize.StepBased 13sp–18sp), RowAmount (ModamFigures, tnum, bounded width), DetailRow (label/value pair), Gauge (arc canvas, animated fill, red→amber→green zones), StatusPill (Radius.pill, color-coded bg+text)
- [ ] Dashboard screen rewritten: HeroPanel with balance gauge + proxy StatusPill + device count + today usage + disk + load/temp; tile grid below (6 tiles: Status, Usage, Cost, Bill, Balance, Clients/Disk) using Panel
- [ ] SetupScreen restyled: new tokens, dark theme, Modam font, proper spacing
- [ ] LockScreen restyled: same treatment
- [ ] Back-navigation scaffold added: top bar with back arrow on detail screens (all screens except Dashboard), state-based back stack
- [ ] App compiles; Dashboard is fully polished and navigable; floating tab bar works; back-button returns to Dashboard from any screen
