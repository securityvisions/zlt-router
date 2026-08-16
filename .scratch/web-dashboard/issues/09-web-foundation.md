# 09 — Web foundation: SPA shell + design system + auth + deploy

**What to build:** The Vite + React + Tailwind RTL SPA in `web/`, served same-origin from the router's `/www/noc`. Dark-mode-only OLED design system (green #22C55E accent, data-dense) per ui-ux-pro-max. A token setup screen stores the API token (localStorage); the API client speaks Basic auth to the Router API. `npm run build` produces `dist/`; `deploy.sh` syncs it to `/www/noc`. The shell renders live `/status` to prove the seam.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] Vite + React + Tailwind scaffold; RTL document (lang=fa, dir=rtl).
- [ ] Setup screen validates the token via a live call; wrong token → clear error.
- [ ] API client uses Basic auth; `usePoll` hook polls with error surfacing.
- [ ] `web/npm run typecheck`, `web/npm test`, `web/npm run build` all green.
- [ ] `deploy.sh` builds and syncs dist to `/www/noc` (router host overrideable).
