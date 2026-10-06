# Samsung QLED TV (Q70C Tizen OS) — Complete Architecture & Operations Manual

This document is the canonical reference for the Samsung Smart TV on the home network, its Tizen OS developer environment, sideloaded applications ecosystem, and the autonomous router-hosted IPTV proxy architecture.

---

## 1. Device Profile & Hardware Specifications

| Attribute | Specification |
|---|---|
| **Commercial Model** | Samsung Q70C QLED 4K (2023) |
| **Exact Hardware Code** | `QA55Q70CAUXZN` |
| **Model Code / Series** | `23_NKM2_QTV_T09` |
| **Display Panel** | 55" 4K QLED (3840x2160, 120Hz, HDR10+, FreeSync Premium) |
| **Operating System** | Tizen OS 9.0 (Architecture: 32-bit `armv7` / `arm_32`) |
| **DUID (Device Unique ID)** | `uuid:cd8c3e57-f1f0-492a-a752-d03655f55c09` |
| **LAN IPv4 Address** | `192.168.1.105` (Static DHCP reservation on AX3000T) |
| **Wi-Fi MAC Address** | `c8:12:0b:32:7c:f2` |
| **Smart Hub Region** | United States (US) |
| **Active Open Ports** | `26101` (SDB / Developer), `8001` (REST API v2), `8002` (SSL REST), `8080`, `7678`, `9197` |

---

## 2. Developer Mode, SDB & Sideloading Architecture

### 2.1. Developer Mode Activation
Samsung Tizen allows unauthorized unsigned/partner sideloading without jailbreak through Developer Mode:
1. Open **Apps** on the TV dashboard.
2. Enter sequential pin **`12345`** using the physical remote or on-screen numeric keypad.
3. In the pop-up modal:
   - **Developer Mode**: `ON`
   - **Host PC IP**: Set to the IP of the workstation running Tizen Studio / Apps2Samsung (e.g., `192.168.1.143`).
     > **RTL Language Trait:** Because the system language is set to Persian (`fa_IR`), the 4 IP octet boxes in the UI format right-to-left. Entering `192.168.1.143` visually appears as `143.1.168.192` in raw string dumps. Verify via REST API: `http://192.168.1.105:8001/api/v2/`.
4. Hold the remote **Power** button for 3 seconds to trigger a cold boot (Samsung logo displays).
5. **Post-Installation Lockdown:** Once apps are deployed, set Host PC IP to **`127.0.0.1`** and reboot. This keeps local proxy services (TizenTube daemon `:8101`) bound internally without seeking a remote PC.

### 2.2. SDB & Tooling Stack
- **Protocol:** SDB (Smart Development Bridge) over TCP port `26101`.
- **Management Software:** `Apps2Samsung` v2.7.9 (Win-x64 portable at `C:\Users\parsa\Downloads\SamsungTV\Apps2Samsung.exe`).
- **Certificate Automation:** Apps are signed with a Samsung Partner Certificate profile containing the TV's DUID (`cd8c3e57-f1f0-492a-a752-d03655f55c09`). This grants Partner-level permissions (e.g., DRM AVPlay, background audio, unrestricted network access).

---

## 3. Installed Sideloaded Applications Inventory

As of September 2026, 21 specialized applications are installed and active on the device:

### 3.1. Media & Streaming
1. **TizenTube** (`xvvl3S1TT1.TizenTubeStandalone`):
   - Standalone ad-free YouTube client.
   - Built-in **SponsorBlock** (skips intros, sponsorships, credits).
   - Built-in **DeArrow** (replaces clickbait thumbnails and titles).
   - 4K 60fps playback with native remote navigation.
2. **Jellyfin AVPlay** (`AprZAARz4r.Jellyfin`):
   - Samsung-optimized Jellyfin client using the native hardware `AVPlay` engine.
   - Direct-plays 4K HDR10+ HEVC/H.264 streams with subtitle passthrough from local home servers.
3. **Stremio** (`newslO9NqF.stremio`):
   - Community-driven torrent and debrid streaming aggregator.
4. **NuvioTV** (`NuvioTV001.NuvioTV`):
   - Modern Netflix-style catalog client for online movie/series streaming.
5. **Flixor** (`FlixTVApp1.Flixor`):
   - Fast web-based media client.
6. **Reiverr** (`JZUbM5WimZ.Reiverr`):
   - Unified media aggregator combining local libraries and web indexes.
7. **KickTV** (`CrKckTV001.KickTV`):
   - Ad-free client for Kick.com live streams with low-latency chat.
8. **Fladder** (`nl.jknaapen.fladder`):
   - Modern Flutter-based alternative front-end for Jellyfin.

### 3.2. IPTV & Video Players
9. **EN-IPTV_Player** (`IPTVPlayer.IPTV`):
   - Primary high-performance IPTV player supporting M3U8, EPG, and group categorization.
   - Configured with the local router feed (`http://192.168.1.1/cgi-bin/tv.m3u8`).
10. **hackTV** (`axAXSQIgQ1.hackTV`):
    - Hackable stream player with raw codec fallback.
11. **VLC-TV** (`madebypatk.vlcweb`):
    - HTML5 media player wrapper.

### 3.3. Gaming & Remote Play
12. **Moonlight-Tizen** (`MoonLightS.MoonlightWasm`):
    - Low-latency GameStream / Sunshine client. Streams 4K 60fps/120fps PC gaming from workstation to TV with Bluetooth gamepad support.
13. **Chiaki-Tizen** (`ChIaKiTiZ0.ChiakiTizen`):
    - Open-source PlayStation 4 and PlayStation 5 Remote Play client.
14. **GameBoy-Emulator** (`gbemutzn01.GBEmu`):
    - Native Tizen GameBoy / GBC emulator with full controller mapping.

### 3.4. System, Network & Web Tools
15. **Overscan** (`org.apps2samsung.overscan`):
    - Specialized Chromium-based web browser designed specifically for Tizen.
    - Masks User-Agent as Desktop Chrome (prevents websites serving restricted mobile/smart-TV layouts).
    - Virtual mouse pointer driven by the remote D-Pad; full on-screen QWERTY keyboard.
16. **FCastReceiver** (`qL5oFoTHoJ.FCastReceiver`):
    - Open-source casting receiver (Chromecast alternative) for streaming media from phone or PC browsers.
17. **HyperTizen** (`io.gh.reisxd.HyperTizen`):
    - Screen capture and LED strip controller for DIY ambient TV backlighting (Ambilight).
18. **Tailscale** (`com.tailscale.tailscale`):
    - Encrypted WireGuard-based mesh VPN client for remote access without port forwarding.
19. **TizenBrew** (`xvvl3S1bvH.TizenBrewStandalone`):
    - Community package manager and user-script injector.
20. **iperf3-TV** (`Iperf3TvAp.iperf3tv`):
    - Network throughput diagnostic tool to measure raw LAN bandwidth between AX3000T router and TV.
21. **Tizengram** (`y3ckmhs1Ds.Tizengram`):
    - Telegram client formatted for TV screens.

---

## 4. Autonomous Router-Hosted IPTV Architecture

Because the TV operates on a **US Region firmware profile**, its physical hardware tuner expects North American **ATSC** digital broadcast signals. It cannot decode Iranian over-the-air digital terrestrial television (**DVB-T / DVB-T2**). Resetting the Smart Hub region to change the broadcast country would instantly wipe all 21 sideloaded applications.

To resolve this permanently, the primary house router (**Xiaomi AX3000T at `192.168.1.1`**) was engineered as an autonomous IPTV proxy and manifest sanitizer.

```
+-------------------------------------------------------------------------+
|                              SAMSUNG TV                                 |
|                       App: EN-IPTV_Player (:80)                         |
+-------------------------------------------------------------------------+
       |                                                ^
       | 1. GET /cgi-bin/tv.m3u8 (Master Index)         |
       | 2. GET /cgi-bin/stream/tv3.m3u8 (Sub-Manifest) |
       | 3. GET /cgi-bin/media/tv3/720p.m3u8            |
       v                                                |
+-------------------------------------------------------+-----------------+
|                       XIAOMI AX3000T (192.168.1.1)                      |
|                                                                         |
|  [uhttpd :80]                                                           |
|    ├── /www/tv.m3u8                   --> Static verified 588 channels  |
|    ├── /www/cgi-bin/tv.m3u8           --> Apple HLS MIME-type injector  |
|    ├── /www/cgi-bin/stream/{slug}     --> Dynamic Rendition Router      |
|    └── /www/cgi-bin/media/{slug}/{res}--> Live Rewriter & Sanitizer:    |
|          • Resolves fresh edge URL on-demand (0s stale)                 |
|          • Rewrites 16-digit sequence to safe 9-digit modulus           |
|          • Rewrites relative .ts paths to absolute CDN URLs             |
|                                                                         |
|  [sing-box :12345] (Transparent Proxy Core)                             |
|    ├── Direct Rules: telewebion.{com,net,ir}, sepehrtv.ir, anten.ir     |
|    └── Direct DNS: Resolved via 192.168.70.1 (ZLT X28 Iranian SIM)      |
+-------------------------------------------------------------------------+
       |                                                |
       | Live manifest queries                          | 4. Direct video download
       v                                                v
+-----------------------------+               +---------------------------+
|    TELEWEBION API & NCDN    |               |  ARVAN / TELEWEBION CDN   |
| (ncdn.telewebion.net/live/) |               |  (Raw .ts segment chunks) |
+-----------------------------+               +---------------------------+
```

### 4.1. The Three Critical Failure Modes & Fixes

#### Failure Mode A: The 32-Bit Signed Integer Overflow Bug
- **Symptom:** Streams played for exactly one segment (2 seconds), then stalled on "buffering" indefinitely.
- **Root Cause:** Samsung's native `AVPlay` engine (used by Tizen Web media players and Shaka Player) stores `#EXT-X-MEDIA-SEQUENCE` as a **signed 32-bit integer** ($\max = 2,147,483,647$). Telewebion generates this sequence value from microsecond timestamps (e.g. `1789388674130817` — 16 digits). This overflows the integer arithmetic, corrupting the playback buffer calculation after the first chunk.
- **Engineered Solution:** The router's `/www/cgi-bin/media` script intercepts the media playlist and replaces the 16-digit sequence with its last 9 digits via `sed -E 's/EXT-X-MEDIA-SEQUENCE:[0-9]{7}([0-9]{9})/EXT-X-MEDIA-SEQUENCE:\1/'`. Because the resulting number is always below $1,000,000,000$, it fits within the signed 32-bit boundary without overflowing, enabling infinite uninterrupted playback.

#### Failure Mode B: Non-Standard HLS Tags (Shaka Error 4016)
- **Symptom:** Shaka Player failed immediately upon loading the stream with `INVALID_HLS_TAG (Error 4016)`.
- **Root Cause:** Telewebion's upstream packager serves the version tag without the mandatory hash symbol (`EXT-X-VERSION:6` instead of `#EXT-X-VERSION:6`), plus an unauthorized `NAME="..."` attribute inside `#EXT-X-STREAM-INF`.
- **Engineered Solution:** The router sanitizes the master and child manifests on the fly, prepending the hash `#` and stripping illegal attribute blocks.

#### Failure Mode C: Stale Ephemeral Edge Routing (HTTP 403)
- **Symptom:** Channels worked when freshly configured, but returned HTTP 403 Forbidden 1–2 minutes later.
- **Root Cause:** Static playlists pointed to specific edge node hostnames (`live-aburayhanXXXX.telewebion.net`). Telewebion rotates and expires individual edge sessions within 120 seconds.
- **Engineered Solution:** Abandoned background cron scrapers. The `/www/cgi-bin/media` script executes **dynamically on-demand** when the TV requests a segment playlist. It queries `https://ncdn.telewebion.net/{slug}/live/playlist.m3u8` in real-time ($<200\text{ ms}$), obtains the active live edge node, and converts all `.ts` chunk paths to absolute CDN URLs.

### 4.2. Bandwidth Preservation Architecture
Notice that **no video binary data passes through the router's CPU or memory**.
- Only the lightweight text playlist files ($\sim 1\text{ KB}$ every 2–4 seconds) pass through the router CGI script.
- The heavy MPEG-TS video chunks (`.ts` files, $300\text{ KB} - 1.5\text{ MB}$ each) are downloaded **directly by the Samsung TV from Telewebion's CDN servers**.
- Router CPU utilization remains $<1\%$.

### 4.3. Router Server Components Inventory

#### 1. Playlist Endpoint (`/www/cgi-bin/playlist`)
Serves the master index with correct Apple HLS MIME-type:
```sh
# Access URL: http://192.168.1.1/cgi-bin/tv.m3u8 (or http://192.168.1.1/tv.m3u8)
Content-Type: application/vnd.apple.mpegurl; charset=utf-8
Access-Control-Allow-Origin: *
```

#### 2. Channel Stream Router (`/www/cgi-bin/stream`)
Maps requested slugs into multi-bitrate resolution options (480p, 720p, 1080p):
```sh
#!/bin/sh
slug=$(basename "${PATH_INFO:-}" .m3u8)
[ -z "$slug" ] && slug="$QUERY_STRING"

echo "Content-Type: application/vnd.apple.mpegurl; charset=utf-8"
echo "Access-Control-Allow-Origin: *"
echo "Cache-Control: no-cache"
echo ""
cat << SUBEOF
#EXTM3U
#EXT-X-VERSION:6
#EXT-X-STREAM-INF:BANDWIDTH=1240800,RESOLUTION=854x480,CODECS="avc1.4d401f,mp4a.40.2"
http://192.168.1.1/cgi-bin/media/${slug}/480p.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1861200,RESOLUTION=1280x720,CODECS="avc1.4d401f,mp4a.40.2"
http://192.168.1.1/cgi-bin/media/${slug}/720p.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2756600,RESOLUTION=1920x1080,CODECS="avc1.4d4028,mp4a.40.2"
http://192.168.1.1/cgi-bin/media/${slug}/1080p.m3u8
SUBEOF
```

#### 3. Real-Time Sanitizer & Segment Rewriter (`/www/cgi-bin/media`)
```sh
#!/bin/sh
path="${PATH_INFO#/}"
slug="${path%%/*}"
res="${path##*/}"
res="${res%.m3u8}"
[ -z "$res" ] && res="720p"

# Map special slug aliases (e.g. Tamasha is named hdtest internally)
real_slug="$slug"
[ "$slug" = "tamasha" ] && real_slug="hdtest"

# Fetch live edge URL from Telewebion on-demand
final=$(curl -sk -m 4 -o /dev/null -w '%{url_effective}' -L "https://ncdn.telewebion.net/${real_slug}/live/playlist.m3u8")
base="${final%/*}"

if [ -z "$base" ] || [ "$final" = "https://ncdn.telewebion.net/${real_slug}/live/playlist.m3u8" ]; then
  echo "Status: 502 Bad Gateway"
  echo "Content-Type: text/plain"
  echo ""
  echo "Failed to resolve live edge for $slug"
  exit 0
fi

echo "Content-Type: application/vnd.apple.mpegurl; charset=utf-8"
echo "Access-Control-Allow-Origin: *"
echo "Cache-Control: no-cache"
echo ""

# Trim sequence to 9 digits to prevent 32-bit integer overflow; prepend absolute CDN base
curl -sk -m 4 "${base}/${res}/index.m3u8" \
  | sed -E 's/EXT-X-MEDIA-SEQUENCE:[0-9]{7}([0-9]{9})/EXT-X-MEDIA-SEQUENCE:\1/' \
  | awk -v p="${base}/${res}/" '/^[0-9a-zA-Z_-]+\.ts/ {print p $0; next} {print}'
```

### 4.4. Sing-Box Routing Directives
To ensure Iranian streaming traffic never hits the foreign VPS proxy (which triggers geo-blocking and high latency), the following rules are active in `/etc/sing-box/config.json`:
- **Direct Domain Suffixes:** `telewebion.com`, `telewebion.net`, `telewebion.ir`, `sepehrtv.ir`, `anten.ir`, `lenz.ir`, `irib.ir`, `livekadeh.com`, `wns.live`.
- **DNS Server:** Routed to `dns-direct` (`192.168.70.1` — ZLT X28 cellular DNS) so domain resolution delivers the closest Iranian CDN IP (`185.165.205.129`).

---

## 5. Master IPTV Playlist Structure (`http://192.168.1.1/cgi-bin/tv.m3u8`)

The master playlist contains **588 deep-verified live streams** categorized into the following groups:

1. `🇮🇷 صداوسیما — سراسری (HD / FHD)` (17 Channels):
   - شبکه ۱ HD, شبکه ۲ HD, شبکه ۳ Full HD, شبکه ۴ HD, شبکه ۵ (تهران) Full HD
   - شبکه خبر Full HD, شبکه ورزش Full HD, **شبکه تماشا Full HD** (`slug: tamasha -> hdtest`)
   - شبکه نمایش Full HD, آی‌فیلم Full HD, شبکه نسیم Full HD, شبکه مستند Full HD
   - شبکه پویا و نهال Full HD, شبکه آموزش HD, شبکه سلامت HD, شبکه افق Full HD, شبکه قرآن Full HD
2. `🇮🇷 صداوسیما — استانی` (9 Major Provincial Channels):
   - شبکه فارس (شیراز), شبکه کرمان, شبکه قزوین, شبکه بوشهر, شبکه ایلام, شبکه سمنان
   - شبکه کردستان (سنندج), شبکه سبلان (اردبیل), شبکه باران (گیلان)
3. `🇮🇷 فارسی‌زبان و ماهواره‌ای` (7 Channels):
   - تپش HD, آوانگ HD, صدای آمریکا فارسی, العالم HD, ۴ کرد (موسیقی), افرا فیلم HD, 4U TV
4. `⚽ ورزشی` (70 Channels):
   - International football, racing, combat, and court sports networks.
5. `🎬 فیلم` (60 Channels):
   - 24/7 curated movie and cinema networks.
6. `📺 سریال` (40 Channels):
   - Dedicated drama, sci-fi, and comedy series streams.
7. `🌍 مستند` (60 Channels):
   - Nature, science, history, and geographical documentary networks.
8. `📰 خبری` (60 Channels):
   - Major world news agencies (English, French, Turkish, Arabic).
9. `🎵 موسیقی` (50 Channels):
   - Global music video streams across genres.
10. `🧸 کودک` (50 Channels) & `🎨 انیمیشن` (30 Channels):
    - Kids entertainment, cartoons, and family animation.
11. `🎉 سرگرمی` (50 Channels) & `😂 کمدی` (25 Channels):
    - Variety shows and sitcom streams.
12. `🕌 مذهبی` (30 Channels), `✈️ طبیعت و سفر` (20 Channels), `🔬 علمی` (10 Channels).

---

## 6. Operational Runbook & Maintenance

### 6.1. Adding New IRIB Channels
1. Probe the candidate slug on Telewebion from the router:
   ```sh
   sshpass -p "xirouter123" ssh root@192.168.1.1 "curl -skI 'https://ncdn.telewebion.net/<slug>/live/playlist.m3u8'"
   ```
   If HTTP `302` returns, the stream exists.
2. In `/www/tv.m3u8`, add:
   ```m3u
   #EXTINF:-1 group-title="🇮🇷 صداوسیما — سراسری (HD / FHD)",<Display Name>
   http://192.168.1.1/cgi-bin/stream/<slug>.m3u8
   ```
3. Refresh the playlist in `EN-IPTV_Player` on the TV.

### 6.2. TV SDB Health Check from Workstation
```cmd
cd C:\tizen-studio\tools
sdb connect 192.168.1.105:26101
sdb devices
# Output should show: 192.168.1.105:26101    device    QA55Q70CAUXZN
```

### 6.3. Quick Diagnostic Checklist
| Problem | Cause | Solution |
|---|---|---|
| Stream stalls after 2 seconds | 16-digit sequence number overflow | Verify channel URL points to `/cgi-bin/stream/...` (which uses `/cgi-bin/media` sequence truncation). |
| Player reports "Connection Failed" | Missing HLS MIME header | Use `http://192.168.1.1/cgi-bin/tv.m3u8` instead of raw static file URL. |
| Player reports "Error 4016" | Malformed `#EXT-X-VERSION` | The router dynamic rewriter strips and corrects this on the fly. Verify `/www/cgi-bin/media` is executable (`chmod +x`). |
| Iranian channels fail to load | Direct routing bypassed | Verify `sing-box` rules include `telewebion.net` and `telewebion.com` under `outbound: direct`. |
| SDB connection refused | TV lost developer IP | Re-enter developer menu in Apps (`12345`) and ensure Host PC IP is set to `192.168.1.143`. |
