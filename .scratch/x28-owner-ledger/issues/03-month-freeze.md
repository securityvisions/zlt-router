# 03 — Month-end freeze + frozen-page browser

**What to build:** The existing first-Friday-after-Jalali-month-end trigger additionally freezes the completed month's ledger page to an immutable snapshot file. A `/ledger` command lists frozen months as tappable buttons; tapping renders that page exactly as published — history immune to all cache pruning forever.

**Blocked by:** 02 — freezes the rendered ledger card.

**Status:** resolved

- [ ] Freeze fires once per Jalali month (marker), writes the page under the ledger store, survives reboot
- [ ] `/ledger` lists months newest-first; tapping any renders the frozen page verbatim
- [ ] Same-Friday coexistence verified with weekly digest + people auto-send (no suppression/duplication)
- [ ] Suite green; deployed with health gate GREEN
