# Research — Antigravity "not available in your location" fix

**Date:** 2026-08-25 · **Trigger:** PC sign-in to Google Antigravity IDE failed with
"Sorry, this account is ineligible to use Antigravity… not currently available in
your location." · **Vantage:** home network, egress confirmed Frankfurt DE
(ipinfo.io from the PC shows 85.121.124.158, M247).

## Question

Why is the account blocked when the IP is already German, and what actually fixes it?

## Findings

### 1. What the eligibility check uses

- **Account-level country association is the decisive signal.** The official FAQ
  describes availability as "for personal Google accounts in approved geographies"
  and links Google's Country Association Form as the way to change the associated
  region. Source: https://antigravity.google/docs/faq/
- The account has a **"home country" permanently associated for legal/billing
  purposes**; if undefined or set to an unsupported region, Antigravity blocks it.
  A second signal: the **request IP** — a block can trigger when account country
  conflicts with the IP, or the IP looks fully anonymized (datacenter ranges).
  Source: https://discuss.ai.google.dev/t/125120
- **Per-account, not per-IP:** one paid account blocked while another worked on
  the same device/network — device, browser, and IP ruled out as sole causes.
  Source: https://discuss.ai.google.dev/t/136109
- Age 18+ is a separate eligibility axis (official FAQ, above).
- Play Store country: no source ties it to Antigravity — the operative attribute
  is the ToS country association. Cache/locale/client-side tricks: no supporting
  evidence anywhere — treat as myth.

### 2. Supported regions

Official FAQ lists ~220 countries/territories; **Germany supported** (Europe, 47
countries). Iran absent from every region. Source: https://antigravity.google/docs/faq/

### 3. Workarounds, by evidence strength

1. **Country Association Form** (policies.google.com/country-association-form) —
   the only Google-sanctioned remedy, linked from the official FAQ and endorsed
   in the forum reply. Reported turnaround ~30 min–24 h with email notification
   (secondary source: apipod.ai blog — unverified). Approval odds for Iran→DE
   unknown.
2. **Fresh Google account created while egressing from a supported region** —
   strongly implied by the per-account evidence, not primary-verified.
3. **WARP: skip.** Cloudflare's own docs state WARP is not designed to hide
   location; it egresses near the true location, and anonymized-looking IPs are
   themselves a trigger. Sources:
   https://cloudflare-docs.cloudflare-docs.workers.dev/client-ip-geolocation/
   https://blog.cloudflare.com/geoexit-improving-warp-user-experience-larger-network/

### 4. Residual caveat for our setup

Our Frankfurt egress is a **datacenter IP (M247)**. If both the form and a fresh
account fail, the datacenter-looking IP is the next suspect (per §1's anonymized-
range trigger), not the router config. No primary source quantifies this risk.

Open unresolved report of the same error: google-antigravity/antigravity-cli#297.

## Decision (2026-08-25)

Run both sanctioned paths in parallel; zero network changes — the existing
GEOSITE,google rule already egresses DE for exactly these domains:

- **Phase 1:** submit the Country Association Form (Iran → Germany) from the PC
  on the normal home network; watch for the email; retry Antigravity.
- **Phase 2:** create a fresh Google account on the same network (signup sees
  Frankfurt → DE association) and sign into Antigravity with it immediately.
- **Phase 3 (only if both fail):** read-only engine connection watch during a
  sign-in attempt to check for egress leaks; then consider the datacenter-IP
  caveat above.
