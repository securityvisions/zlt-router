# 01 — Privacy eye toggle (blur sensitive data)

**What to build:** A fixed eye button (👁/🙈) in the dashboard's top-right corner. One click toggles a strong 6px blur over every personal value on screen — MAC addresses, owner/person names, device hostnames, and IPs in the devices and ledger cards — so a demo video can be recorded with the toggle on and nothing sensitive readable. The blur persists across the 30s auto-refresh; the button flips to a crossed-eye with a "privacy on" pill so the state is obvious on camera.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [x] Clicking the eye toggles body-level blur state; icon swaps 👁 → 🙈 with a "privacy on" pill
- [x] Blur state persists across the 30s auto-refresh (localStorage)
- [x] Devices card: hostname, MAC, IP, owner chip text, assign-editor person chips and name input are blurred when on
- [x] Ledger card: person names in all month/range/year views and MACs in the per-device breakdown are blurred when on
- [x] Toggle is a fixed, always-visible button (doesn't scroll away during recording); toggling back restores all text instantly
- [x] Deployed; JS parses; verified in a browser that toggling blurs and un-blurs