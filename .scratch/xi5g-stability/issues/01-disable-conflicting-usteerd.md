# 01 - Disable Conflicting usteerd on Split-SSID Radios

Status: resolved
Assignee: agent
Type: task

## Answer

1. **Root Cause Confirmed:**
   - `usteerd` was repeatedly issuing 802.11v BSS Transition requests and kicking clients off `phy1-ap0` (`XI-5G`) because its configured threshold `band_steering_min_snr '-68'` was evaluated whenever signal dipped around -70 dBm.
   - Because AX3000T uses **split SSIDs** (`XI-5G` on 5GHz vs `XI-2G` on 2.4GHz), 802.11v transition between different SSIDs is invalid per Wi-Fi specifications and caused devices to drop off Wi-Fi repeatedly.
2. **Resolution Applied:**
   - Stopped `usteerd` (`/etc/init.d/usteer stop`).
   - Disabled `usteerd` from autostart (`/etc/init.d/usteer disable`).
   - Updated `usteer.@usteer[0].enabled='0'` and committed UCI.
   - Verified that clients stay reliably connected to `XI-5G` with high throughput (~624–1002 Mbps) without any disconnect storms in `logread`.
Blocked by: none

## Question

Why was `usteerd` repeatedly disconnecting clients from `XI-5G`, and how should AX3000T's Wi-Fi configuration be reconciled with split SSIDs (`XI-5G` on 5GHz vs `XI-2G` on 2.4GHz)?

### Findings & Context

1. `logread` logs show continuous disconnections:
   `user.info usteer: station 22:7d:f2:30:d3:3b disconnected from node hostapd.phy1-ap0`
   `user.info usteer: station f4:28:9d:60:61:cb disconnected from node hostapd.phy1-ap0`
2. `usteerd` is an 802.11v/k band steering daemon designed exclusively for **Single-SSID** environments where 2.4GHz and 5GHz share the exact same SSID name.
3. On AX3000T, the user deliberately named them `XI-2G` (2.4GHz) and `XI-5G` (5GHz). When a client connects to `XI-5G` and signal fluctuates around -70 dBm, `usteerd` evaluates `band_steering_min_snr '-68'` (misconfigured negative dBm value) and issues 802.11v BSS Transition or kick deauths towards `phy0-ap0`. Because `phy0-ap0` broadcasts a different SSID (`XI-2G`), the client drops Wi-Fi and experiences connection drops.
