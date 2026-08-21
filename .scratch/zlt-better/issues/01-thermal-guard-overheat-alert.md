# 01 — Thermal guard + overheat alert

**What to build:** `X28` reads `mtk-soc-temp` every minute, logs to `Telemetry log` (`ts|temp|load|rsrp`), and sends a Telegram Card via `tg-notify.sh` when >75°C (with `Link` RSRP + load) — you see heat before throttling kills 5G.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [x] `x28-thermal.sh` reads `thermal_zone*/temp` and reports °C; unit test with fixture temps.
- [x] Procd service `x28-thermal` samples every 60s, appends to `Telemetry log` (and `usage` dir for history), never blocks boot.
- [x] Alert fires once per overheat episode (>75°C) with Card formatting, via `tg-notify.sh` best-effort; health gate stays GREEN after deploy.
- [x] Canonical copy in `router/x28/` + deploy wiring; no secrets.
