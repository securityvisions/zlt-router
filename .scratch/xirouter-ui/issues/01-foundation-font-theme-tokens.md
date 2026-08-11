# 01 — Foundation: font + theme tokens + typography + RTL

**What to build:** the app renders with the Modam variable font, the new dark-first color palette, all design tokens (Space, Radius, Motion, Hero), a complete Material3 typography scale (7 text weights + 5 narrow-figure weights with `tnum`), and forced RTL at the root. The XML theme switches to Material3 DayNight. Existing screens still use the old component code, but they compile and display the new colors, font, and layout direction — a visual regression pass confirms every surface picks up the new tokens.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] `modam.ttf` (301 KB variable font) and three XML wrappers (`modam_heavy`, `modam_semibold`, `modam_medium`) copied from chandtoman into `res/font/`
- [ ] `Theme.kt` rewritten: Space/Radius/Motion/Hero token objects; full Modam typography scale (15 M3 styles → Modam + ModamFigures + weights + letterSpacing=0.sp + tnum); dark palette (Smart Home/IoT: #0F172A bg, #1E293B primary, #22C55E accent, #F59E0B warning, #EF4444 destructive) and derived light palette; `XirouterTheme` composable passes tokens, typography, shapes, and color scheme
- [ ] `Format.kt` rewritten: `bidi()` (FSI/PDI isolates), `ltrFigure()` (LRI/PDI), `figureStyle()` (ModamFigures + tnum + color + weight), `faCompact()` with Persian group separators, `GroupedNumber` VisualTransformation for text fields, `TABULAR` font-feature constant
- [ ] `MainActivity.kt`: forced RTL via `CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl)` wrapping the app content
- [ ] `themes.xml`: switched from `android:Theme.Material.Light.NoActionBar` to `Theme.Material3.DayNight.NoActionBar`
- [ ] App compiles clean; existing screens render with new dark theme + Modam font; RTL is forced; no visual regressions in data flow
