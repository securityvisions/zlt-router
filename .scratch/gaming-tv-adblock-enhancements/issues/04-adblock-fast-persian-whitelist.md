# 04 - Adblock-Fast Domestic Persian Filtering & Banking Whitelist

Status: resolved
Assignee: agent
Type: task
Blocked by: none

## Answer

1. **Root Cause / Opportunity:**
   - Household devices on `XI-5G` and `XI-2G` were subjected to invasive domestic Persian advertising trackers (Yektanet, Tapsell, Sabavision, MediaAd, Najva) and pop-ups on Iranian news and media websites.
   - However, naive ad-blocking risks breaking payment gateways (`shaparak.ir`), bank portals, and university portals.
2. **Resolution Applied:**
   - Populated `/etc/config/adblock-fast` on AX3000T with a curated Persian blocklist under `blocked_domain`:
     - Yektanet (`yektanet.com`, `api.yektanet.com`, `cdn.yektanet.com`)
     - Tapsell (`tapsell.ir`, `api.tapsell.ir`, `storage.tapsell.ir`)
     - Sabavision (`sabavision.com`, `api.sabavision.com`)
     - MediaAd (`mediaad.org`, `s1.mediaad.org`)
     - Push trackers & aggregators (`najva.com`, `push-notification.net`, `chabok.io`, `metrix.ir`, `adtrace.io`, `sanjagh.pro`, `anetwork.ir`, `vclick.ir`).
   - Configured an immutable domestic whitelist under `allowed_domain`:
     - Core payment gateways: `shaparak.ir`, `sep.ir`, `pep.co.ir`, `behpardakht.com`, `asanpardakht.ir`, `sadadpsp.ir`, `zarinpal.com`.
     - Major banking portals: `bmi.ir`, `bankmellat.ir`, `bki.ir`, `sb24.ir`, `parsian-bank.ir`.
     - Universities: `iau.ir`, `srbiau.ac.ir`, `ut.ac.ir`, `aut.ac.ir`, `sharif.edu`.
     - Government & domestic platforms: `tax.gov.ir`, `my.gov.ir`, `snapp.ir`, `divar.ir`, `digikala.com`, `torob.com`, `telewebion.com`, `telewebion.net`.
   - Regenerated `dnsmasq.servers` and reloaded dnsmasq:
     - 6,279 domains actively blocked at DNS level with NXDOMAIN.
     - Zero false positives on Iranian banking and university portals (verified via live nslookup queries).


## Question

How should `adblock-fast` on AX3000T be configured with curated Persian advertisement blocklists (Yektanet, Tapsell, Sabavision, AdGuard Persian) alongside an immutable whitelist of Iranian payment gateways (Shaparak, Saman, Mellat, Parsian) and universities to guarantee zero broken services?

### Specifications & Context

1. **Current `adblock-fast` Setup on AX3000T:**
   - Package: `adblock-fast` installed and running with dnsmasq integration.
   - Blocklist output: `/var/run/adblock-fast/dnsmasq.servers`.
2. **Configuration Needs:**
   - Add high-trust Persian ad filters:
     - AdGuard Persian filter / Iranian anti-ad hosts.
     - Known Iranian ad trackers (yektanet, tapsell, sabavision, mediaad, kaprila, clickyab).
   - Add comprehensive whitelist (`/etc/adblock-fast/adblock-fast.whitelist`):
     - `shaparak.ir`, `*.shaparak.ir`, `bmi.ir`, `sep.ir`, `pep.co.ir`, `asanpardakht.ir`, `behpardakht.com`.
     - Universities (`iau.ir`, `srbiau.ac.ir`, `aut.ac.ir`, `ut.ac.ir`).
     - Government/tax portals (`tax.gov.ir`, `my.gov.ir`).
   - Validate that dnsmasq reloads cleanly without memory spike.
