# Xirouter UI Overhaul — Spec

Status: ready-for-agent

## Problem Statement

The Xirouter app's UI is visually poor: stock system font (no Persian-specific font), only 4 color tokens set, no RTL enforcement in Compose, emoji icons, 781-line monolithic Ui.kt with no shared components, bare Canvas charts with no labels/animation, broken back-navigation on detail screens, and a legacy XML theme. The user wants it to look like chandtoman (the reference Android app): Modam variable font, design tokens (Space/Radius/Motion), dark-first OLED palette, floating-island tab bar with Canvas-drawn icons, Panel/Band/SectionHead component patterns, animated charts with axis labels, and proper RTL.

## Design decisions (from grilling session)

- **Font**: Modam (variable, from chandtoman; wght 200-900, wdth 70-100). Narrow-figure variant (90% width) for all monetary/GB numbers.
- **Palette**: Dark-first, system-follow. Smart Home/IoT from ui-ux-pro-max: slate-navy backgrounds (#0F172A bg, #1E293B primary), green (#22C55E) for UP/healthy, amber (#F59E0B) for warnings, red (#EF4444) for DOWN/error. Derived light variant with inverted bg/fg.
- **Tokens**: Adopt chandtoman's exact Space (4→40dp), Radius (pill/field/card/group/sheet), Motion (enter/exit/fast/medium) values.
- **Navigation**: Floating-island bottom tab (28dp-radius clip, 12dp shadow, 5 custom Canvas-drawn network glyphs: grid/chart-line/lightning/sliders/gear).
- **File structure**: Mirror chandtoman — Theme.kt (tokens+typography+colors), TabBar.kt (nav+icons), Ui.kt (screens+components), Charts.kt (chart composables), Format.kt (bidi+numbers).
- **Components**: Adopt chandtoman's Panel, Band+bandShape, SectionHead, RowTitle, RowAmount, DetailRow. New: Gauge (arc with zones), StatusPill (proxy/tier), LiveRateCard (real-time throughput with pulse). Hand-drawn Canvas icons matching chandtoman's pen() style.
- **Charts**: Full polish — axis labels in ModamFigures, animated entry, gridlines, chart captions, hero-colored legends. Line (balance drain, today curve), area (hourly usage), bar (per-device monthly, monthly cost), streaming area+gauge (live bandwidth).
- **RTL**: Forced via CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl). Persian bidi helpers (bidi, ltrFigure) from chandtoman's Format.kt.
- **Scope**: Complete rewrite of Theme.kt, Format.kt, Ui.kt, Charts.kt, TabBar.kt (new), MainActivity.kt (RTL), themes.xml. No changes to business logic (AppModel, ApiClient, Store, Db, Notify, Notifier, BalanceTier, LiveRate).

## Out of scope

- Changes to data layer or business logic.
- New screens beyond what already exists.
- Remote relay (phase 2, already deferred).
