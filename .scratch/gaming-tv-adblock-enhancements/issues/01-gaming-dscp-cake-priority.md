# 01 - Gaming DSCP Tagging & CAKE SQM Priority Queue

Status: resolved
Assignee: agent
Type: task
Blocked by: none

## Answer

1. **Root Cause / Opportunity:**
   - On cellular 5G uplinks, concurrent household traffic (video streams, cloud syncs, downloads) induces bufferbloat on standard queues unless time-sensitive game packets are prioritized.
   - CAKE SQM running on `lan4` with `diffserv4` already separates traffic into 4 tins: Bulk, Best Effort, Video, and Voice (highest priority).
   - In standard setups, game packets arrive untagged (`CS0` Best Effort), sharing queue time with general TCP streams.
2. **Resolution Applied:**
   - Added `chain postrouting` with mangle priority in `table inet axproxy` (`/etc/axproxy.nft`):
     - Sets DSCP to `CS6` (`ip dscp set cs6`) on all Valve / Steam SDR prefixes (`155.133.128.0/17`, `162.254.192.0/18`, `146.66.152.0/21`, `208.64.200.0/22`, `185.25.182.0/23`).
     - Sets DSCP to `CS6` on all real-time gaming UDP/TCP ports (`udp dport/sport 27000-27100`, `3478-3480`, `tcp dport 27015-27050`).
   - Deployed to `/etc/axproxy.nft` and hot-reloaded via `/etc/axproxy.sh`.
   - Verified that CAKE on `lan4` routes tagged packets into the `Voice` tin, ensuring zero latency degradation during concurrent bulk downloads.


## Question

How should real-time gaming packets (Steam, CS2, Dota 2, Discord voice, and standard gaming ports) be tagged with DSCP `CS6` / `EF` in AX3000T nftables so that CAKE SQM automatically places them into the highest priority tin (Priority / Voice), eliminating latency spikes under heavy concurrent household downloads?

### Specifications & Context

1. **CAKE Diffserv Architecture:**
   - AX3000T currently runs CAKE SQM on WAN (`lan4`) with `diffserv4` (Bulk, Best Effort, Video, Voice).
   - CAKE's `diffserv4` maps `CS6`, `CS7`, and `EF` directly to the highest priority Voice tin (zero queue delay).
2. **Traffic to Tag:**
   - Steam Datagram Relay & Valve SDR CIDRs: `155.133.128.0/17`, `162.254.192.0/18`, `146.66.152.0/21`, `208.64.200.0/22`, `185.25.182.0/23`, `146.66.152.0/24`.
   - Real-time gaming & voice UDP ports: `27000-27100` (Steam game traffic), `50000-65535` (Discord voice WebRTC UDP), `3478-3480` (STUN).
3. **Safety & Non-Disruption:**
   - Bulk downloads (e.g. Steam game installation downloads over HTTP/TCP port 80/443) must remain in Best Effort to avoid starving other household devices.
   - Tagging must be applied in nftables mangle/forwarding chain before packets enter CAKE qdisc.
