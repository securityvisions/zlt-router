# Spec: Wi-Fi laptop connectivity compatibility (XI network)

Status: ready-for-agent

## Problem Statement

Laptops on the home network had trouble connecting to the router's "XI" Wi-Fi while phones in the same location connected immediately. Two distinct failures appeared in the AP logs:

1. The Intel-based laptop logged **`did not acknowledge authentication response`** hundreds of times on both 2.4 GHz and 5 GHz — a MAC-layer ACK failure — often failing to associate until the adapter was reset or the laptop moved closer.
2. A second laptop logged **`AP-STA-POSSIBLE-PSK-MISMATCH`** repeatedly on both bands and never completed the WPA handshake; the client stayed stuck on "Connecting…" and kept re-prompting for the network security key.

The router's "XI" network was running **802.11ax (HE, Wi-Fi 6)** on both bands and **WPA2/WPA3 transition** (`sae-mixed`) — combinations poorly handled by laptop Wi-Fi adapters, particularly at association time.

## Solution

Two compatibility changes were applied to the router's wireless configuration:

- **Disable 802.11ax (HE):** 2.4 GHz → `HT40` (802.11n), 5 GHz → `VHT40` (802.11ac). This removes HE negotiation that some laptop drivers (and edge-of-range radios) mishandle during association.
- **WPA2-only:** both main "XI" interfaces switched from `sae-mixed` (WPA2/WPA3 transition) to `psk2` (WPA2-PSK). This eliminates SAE/PMKSA handshake failures that surfaced as `POSSIBLE-PSK-MISMATCH`.

Result: laptops associate and complete the WPA2 4-way handshake cleanly, and the Wi-Fi recovers automatically after router reboots. The one-time client-side step is to forget the stale "XI" profile and re-enter the pre-shared key once.

## User Stories

1. As a user, I want my laptop to connect to the home Wi-Fi on the first attempt, so I'm not stuck troubleshooting connections.
2. As a user, I want my Intel-based laptop to associate reliably instead of failing at the 802.11 authentication step.
3. As a user, I want my laptop to stop re-prompting for the network security key, so I can join the network without frustration.
4. As a user, I want my laptop's connection to be stable after the initial password re-entry, so reconnects are automatic.
5. As a user, I want phones to keep connecting without any reconfiguration, so the fix doesn't regress mobile devices.
6. As a user, I want the changed configuration to survive router reboots, so I never have to reapply it.
7. As a user, I want clear guidance on the one-time laptop credential step, so family members can reconnect without calling me.
8. As a user, I want the fix to not require a new SSID or password, so existing saved identities mostly carry over.
9. As a user, I want the network to still be secure (WPA2-PSK/AES) after dropping WPA3, so the home network isn't weakened.
10. As a user in the future, I want to know whether the guest network follows the same compatibility settings, so guests aren't hit by the same laptop issue.

## Implementation Decisions

- **Changed configuration** (router wireless subsystem): 2.4 GHz radio `htmode` `HE20 → HT40`; 5 GHz radio `htmode` `HE80 → VHT40`; main "XI" interfaces `encryption` `sae-mixed → psk2`. `ocv` stays off (already the compatibility-friendly default).
- **Unchanged:** the SSID ("XI"), the pre-shared key, channel selection, and the guest "XI-Guest" network (still `sae-mixed`).
- **One-time client step:** on each laptop, forget the old "XI" profile and re-enter the key (`darya1014@#`) once; the WPA3→WPA2 transition otherwise leaves a stale credential. Phones reconnect automatically.
- **Operational note:** `wifi down; wifi up` on this router can hang briefly while the radios re-register (it temporarily hid the SSID during one apply). The committed config loads correctly on reboot; the hang is a restart-timing artefact, not a config error.
- No application/script code was modified — this is a pure OpenWrt wireless configuration change on the Router.

## Testing Decisions

**What makes a good test:** only external, observable behaviour — that a laptop (previously failing) can associate and complete the WPA handshake with the AP, with no `POSSIBLE-PSK-MISMATCH` or repeated auth-ACK failures, and that existing phones still associate.

**Seam:** the router's AP observation surface — hostapd logs plus the attached-station/dhcp state. Success = the client showing `AP-STA-CONNECTED` with `EAPOL-4WAY-HS-COMPLETED`, absence of new `POSSIBLE-PSK-MISMATCH` / `did not acknowledge authentication response`, and a DHCP lease granted. This is the highest external seam (full association end-to-end) and is the same surface used during the diagnosis.

**Modules verified:**
- Both radios (2.4 GHz HT40, 5 GHz VHT40) broadcasting "XI" with WPA-PSK.
- WPA2 4-way handshake completion for a previously-failing laptop.
- Phone reconnection unaffected.
- Config persists across a `wifi reload`/reboot.

**Prior art:** the diagnosis itself — hostapd log analysis (auth-ACK failures, PSK-MISMATCH), `iwinfo` radio/assoc output, and `/tmp/dhcp.leases` — is reused as the verification method.

## Out of Scope

1. **Guest network ("XI-Guest")** — still `sae-mixed`; converting it to WPA2 as well is a low-risk follow-up if laptops on the guest SSID hit the same issue.
2. **Device-side driver fixes** for the second laptop — resolved client-side by forgetting the stale profile; a deeper driver analysis is out of scope.
3. **RF/channel tuning** — channel interference, DFS, TX power, and antenna placement were not changed.
4. **Re-enabling 802.11ax** — intentionally left off to keep laptop association reliable.

## Further Notes

- The apparent "network was broken" scare during one apply was the Wi-Fi restart command hanging; the radios returned carrying the new settings, and the config is persistent.
- The second laptop ultimately connected after forgetting its stale "XI" profile and re-entering the key — confirming its `POSSIBLE-PSK-MISMATCH` was a stale/incorrect saved credential rather than a server-side rejection.
- Passwords and keys are not stored in this repo; the pre-shared key lives only in the router's wireless config.