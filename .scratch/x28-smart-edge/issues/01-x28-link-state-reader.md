# 01 — X28 link-state reader (the seam)

**What to build:** A normalized way to read the X28's live link state (operator, tech 4G/5G, RSRP, 5G-NR RSRP, band, PLMN, signal) from the AX3000T — the foundation everything else reads from. Deployed as /data/proxy/linkstate.sh (X28) and /root/x28link.sh (AX3000T), fixture-testable.

**Blocked by:** None — can start immediately

**Status:** resolved (commit 330c6a8 + follow-up)

- [ ] Running /root/x28link.sh prints operator/tech/rsrp/rsrp_5g/band/plmn for the live link; 14 fixture assertions green.
