# 04 — Charts (balance drain, hourly, per-device, today, monthly cost)

**What to build:** all chart screens are rewritten with axis labels (ModamFigures + tnum), animated line/area/bar drawing, gridlines, chart captions, and hero-colored legends. The chart composable foundation is rebuilt: `AnimatedLineChart` (trend over time with animated path drawing + axis labels + grid), `AnimatedAreaChart` (streaming feel, fade older data), `AnimatedBarChart` (horizontal bars for per-device, vertical bars for monthly cost), all using ModamFigures for axis values. Charts render on the dark theme with green primary lines, gridlines in Outline color, and labels in OnSurfaceVariant.

**Blocked by:** 01, 02

**Status:** ready-for-agent

- [ ] Charts.kt rewritten: AnimatedLineChart (path animation via `Animatable`, x/y axis labels, gridline strokes, caption composable), AnimatedAreaChart (gradient fill with fade), AnimatedBarChart (horizontal + vertical variants), ChartCaption (label + value, labelLarge + ModamFigures)
- [ ] Balance drain chart: animated line with date axis (Persian digits), GB axis, gridlines, hero-green line color
- [ ] Hourly usage chart: area chart with streaming feel, gradient fill, time axis
- [ ] Per-device monthly chart: horizontal bars sorted by GB, device-name labels, ModamFigures GB values
- [ ] Today's curve chart: same style as balance drain, time axis
- [ ] Monthly cost chart: vertical bars, Toman axis with Persian grouping, device-name labels
- [ ] All charts compile and render with the new tokens/font; animation plays on first draw; axis labels are readable in Persian
