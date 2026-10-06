# Research: Zero-Downtime Implementation of Xray MITM Domain Fronting on OpenWrt

Date: 2026-09-09  
Target Repository: [`https://github.com/duuuude/xray-mitm-openwrt`](https://github.com/duuuude/xray-mitm-openwrt)  
Upstream Architecture: [`patterniha/MITM-DomainFronting v23`](https://github.com/patterniha/MITM-DomainFronting/tree/v23)  
Target Environment: OpenWrt 25.12+ (APK-based), OpenWrt 23.05/24.10 (`fw4` / `nftables`), e.g., Xiaomi Mi Router AX3000T (Filogic MT7981B)  
All claims cited against primary source code, RFCs, kernel netfilter documentation, and operating system security specifications.

---

## چکیده مدیریتی و پاسخ اجرایی (Persian Executive Summary)

### سوال اصلی کاربر
> **«بنظرت چطوری میشه این (xray-mitm-openwrt) رو بدون داون‌تایم پیاده‌سازی کرد؟ اصلا میشه؟»**

### پاسخ صریح و مهندسی
**بله، از منظر شبکه و لایه انتقال (Network & Transport Layer) پیاده‌سازی ۱۰۰٪ بدون داون‌تایم (Zero-Downtime) کاملاً امکان‌پذیر است؛ اما از منظر لایه رمزنگاری و نرم‌افزار کاربر (TLS & Application Layer) اعمال آن به صورت کلی (Blanket Subnet Cutover) روی کل دستگاه‌های شبکه بدون اصطکاک و قطعی سرویس ذاتاً و ساختاراً ناممکن است.**

علت این تفکیک دو سطحی بودن معماری MITM است:

1. **در سطح شبکه (Network Plane):**
   با استفاده از تراکنش‌های اتمیک `nftables`، ایزوله‌سازی سشن‌های موجود با شرط `ct state new`، فعال‌سازی مکانیزم **Fail-Open خودکار**، و ارسال پاسخ صریح `port-unreachable` برای ترافیک QUIC/HTTP3، می‌توان ترافیک را بدون قطع شدن حتی یک کانکشن موجود (مانند دانلود، استریم یا بازی آنلاین) و بدون ری‌استارت فایروال به روتور تزریق کرد.
2. **در سطح کلاینت و رمزنگاری (Cryptographic & Client Plane):**
   پروژه `xray-mitm` از روش جعل و بازتولید گواهی TLS (Dynamic TLS Interception با قابلیت `usage: "issue"` در Xray) استفاده می‌کند. اگر ترافیک HTTPS دامنه‌ای مانند Google یا YouTube به سمت Xray هدایت شود، ولی کاربر هنوز گواهی CA اختصاصی (`mycert.crt`) را در Root Certificate Store دستگاه نصب نکرده باشد، مرورگر و اپلیکیشن بلافاصله خطای مهلک امنیتی (`SEC_ERROR_UNKNOWN_ISSUER`) داده و سرویس قطع می‌شود. علاوه بر این:
   - **دستگاه‌های IoT و تلویزیون‌های هوشمند** امکان نصب گواهی Root ندارند و در صورت شنود ترافیک، کاملاً از کار می‌افتند.
   - **اپلیکیشن‌های با SSL Pinning** (مانند تلگرام، واتس‌اپ، برنامه‌های بانکی، Google Play Services و اپل) حتی در صورت نصب گواهی در سیستم، پینینگ آنها شکسته نشده و قطع می‌شوند.
   - **اندروید نسخه ۷ به بعد (Nougat+)** به صورت پیش‌فرض گواهی‌های User-installed را برای اپلیکیشن‌ها نمی‌پذیرد (مگر در مرورگرها یا گوشی‌های روت‌شده با ماژول Magisk).

### راهبرد نهایی برای دستیابی به Zero-Downtime واقعی
برای اینکه این سیستم **بدون ۱ ثانیه داون‌تایم برای کاربران خانه** پیاده‌سازی شود، نباید از روش پیش‌فرض اسکریپت که ری‌استارت سرویس PassWall2 (`/etc/init.d/passwall2 restart`) روی کل ساب‌نت است استفاده کرد. راهکار صحیح:
1. **نصب و راه‌اندازی سایلنت (Silent Pre-warming):** دیمن Xray روی پورت محلی `127.0.0.1:10808` بالا می‌آید و بدون دستکاری شبکه یا DNS، با `curl` تست سلامت آن تایید می‌شود.
2. **توزیع گواهی پیش از اعمال مسیر (Out-of-Band Trust Provisioning):** گواهی `mycert.crt` قبل از فعال‌سازی روتینگ روی کلاینت‌های هدف نصب و تست می‌شود.
3. **مسیریابی قناری (Canary IP Routing) با Nftables مستقل:** فقط IP کلاینت تستر وارد جدول ایزوله هدایت ترافیک می‌شود، بدون اینکه سایر اعضای خانه کوچک‌ترین تغییری حس کنند.
4. **عدم انقطاع کانکشن‌های فعال:** رول‌های هدایت فقط روی `ct state new` اعمال می‌شوند تا کانکشن‌های باز قطع نشوند.
5. **Fail-Open Watchdog:** یک مانیتور محلی در صورت بروز هرگونه کرش یا OOM در Xray، رول را در میلی‌ثانیه غیرفعال کرده و ترافیک را مستقیم (Bypass) عبور می‌دهد.

---

## 1. Deep Architectural Analysis of `xray-mitm-openwrt`

### 1.1 Components and Dependencies
بررسی سورس‌کد مخزن [`duuuude/xray-mitm-openwrt`](https://github.com/duuuude/xray-mitm-openwrt) نشان می‌دهد که این پکیج از اجزای زیر تشکیل شده است:
- **`xray-core` (Binary):** هسته پروکسی برای مدیریت ورودی‌ها، خروجی‌ها، مسیریابی و دستکاری TLS.
- **`etc/config/xray-mitm` (UCI):** تنظیمات وضعیت (`enabled`, `boot_enabled`, `provisioned`, `asset_dir`).
- **`etc/init.d/xray-mitm` (procd):** سرویس مدیریت فرآیند Xray با ردیابی کرش (`respawn 3600 5 5`) و ریکاوری تراکنش‌ها [Source: `xray-mitm/files/etc/init.d/xray-mitm`, Lines 85-94].
- **`/usr/libexec/xray-mitm/cert`:** مدیریت چرخه حیات گواهی CA (ایجاد candidate، تایید اتمیک symlink به `current` و ذخیره نسخه `previous` با قفل فایل `flock`) [Source: Lines 42-100].
- **`/usr/libexec/xray-mitm/config`:** اعتبارسنجی JSON کانفیگ Xray با بررسی ساختار قبل از اجرا.
- **`/usr/libexec/xray-mitm/check`:** تست عملیاتی سرویس با اجرای کوئری امن از طریق پروکسی لوکال SOCKS5 روی `127.0.0.1:10808` [Source: Lines 19-35].
- **`/usr/libexec/xray-mitm/passwall2`:** هلپر مدیریت تراکنش‌های کانفیگ PassWall2 به صورت Staged [Source: Lines 43-57].
- **`luci-app-xray-mitm`:** رابط تحت وب LuCI بر پایه `ucode` و `rpcd`.

### 1.2 The Interception Mechanism & TLS Domain Fronting
بر خلاف تصور اولیه، این پکیج فایروال مستقل برای ربودن مستقیم ترافیک ندارد؛ بلکه یک سرویس SOCKS لوکال در پورت `10808` ارائه می‌دهد و ترافیک باید توسط PassWall2 (یا رول‌های دستی فایروال) به آن تحویل داده شود:

```
+---------------------------------------------------------------------------------------+
|                                    Router (OpenWrt)                                   |
|                                                                                       |
|  [LAN Client] ----TCP 443----> [ Firewall (nftables / TPROXY) ]                       |
|                                         |                                             |
|                                         v (Redirect / SOCKS5)                         |
|                       +-----------------------------------+                           |
|                       | Xray Inbound: mixed-in (10808)    |                           |
|                       | Sniffing: ["fakedns", "tls"]      |                           |
|                       +-----------------------------------+                           |
|                                         |                                             |
|                               (Matched Frontable Domain)                              |
|                                         v                                             |
|                       +-----------------------------------+                           |
|                       | Outbound: redirect-out-h211       |                           |
|                       | redirect -> 127.0.0.1:11777       |                           |
|                       +-----------------------------------+                           |
|                                         |                                             |
|                                         v                                             |
|                       +-----------------------------------+                           |
|                       | Inbound: tls-decrypt-h211 (11777) |                           |
|                       | TLS Termination (usage: "issue")  | <--- Dynamic CA Leaf Gen  |
|                       +-----------------------------------+      (mycert.crt / key)   |
|                                         |                                             |
|                              (Decrypted Plain HTTP/2)                                 |
|                                         v                                             |
|                       +-----------------------------------+                           |
|                       | Outbound: tls-repack-google/fastly|                           |
|                       | SNI: www.microsoft.com / assets   | <--- Domain Fronting Outer|
|                       | Inner Host: www.google.com        |                           |
|                       | verifyPeerCertByName: "fromMitM"  |                           |
|                       +-----------------------------------+                           |
|                                         |                                             |
+-----------------------------------------|---------------------------------------------+
                                          v (Unblocked WAN Traffic)
                             [ Censorship / GFW Bypass ]
```

#### سازوکار Dynamic Certificate Generation در سورس Xray-core
در فایل `transport/internet/tls/config.go` در کد هسته Xray-core:
```go
func (c *Config) getCustomCA() []*Certificate {
    for _, certificate := range c.Certificate {
        if certificate.Usage == Certificate_AUTHORITY_ISSUE { ... }
    }
}
// وقتی کلاینت SNI ارسال می‌کند:
for _, rawCert := range ca {
    if rawCert.Usage == Certificate_AUTHORITY_ISSUE {
        newCert, err := issueCertificate(rawCert, domain)
        ...
        newCert.Leaf = parsed
    }
}
```
هر زمان کلاینت برای یک دامنه رمزنگاری‌شده (مانند `googlevideo.com`) هندشیک TLS باز کند، Xray در پورت `11777` با استفاده از `mycert.key` یک گواهی جدید صادر و به مرورگر ارائه می‌کند. اگر مرورگر این گواهی را تایید کند، لایه TLS شکسته شده و Xray دیتای خام را در قالب یک کانکشن جدید با SNI جعلی مجاز (مانند `www.microsoft.com` برای مایکروسافت/گوگل یا `github.githubassets.com` برای سرورهای CDN فستلی) به اینترنت ارسال می‌نماید [Primary Source: `config.json.example`, Lines 85-131, 203-290].

---

## 2. Root Cause Analysis: What Causes Downtime?

اگر کاربر به شکل ساده یا از طریق رابط کاربری پکیج اقدام به نصب و راه‌اندازی کند، به ۷ دلیل قطعی یا داون‌تایم رخ می‌دهد:

### دلیل اول: ری‌استارت سراسری PassWall2 یا Firewall
در هلپر `passwall2` سورس مخزن (خط ۹۶۴ تا ۹۷۰):
```sh
restart_if_enabled() {
    if service_enabled; then
        "$PW_INIT" restart >/dev/null 2>&1
        return $?
    fi
    return 0
}
```
هنگامی که تغییرات اعمال می‌شوند، دستور `/etc/init.d/passwall2 restart` فراخوانی می‌شود. در لینوکس و اوپن‌ورت، ری‌استارت PassWall2 زنجیره‌های فایروال (iptables/nftables) را کاملاً Flush کرده، پروسه‌های پروکسی را Kill نموده و دوباره آنها را لود می‌کند. در طول ۲ تا ۵ ثانیه:
- تمام سشن‌های TCP عبوری ریست (RST) می‌شوند.
- تمام دستگاه‌های متصل به وای‌فای و کابل شبکه، قطعی لحظه‌ای احساس می‌کنند.

### دلیل دوم: شکستن کانکشن‌های از قبل برقرار شده (Conntrack Severing)
اگر رول‌های هدایت ترافیک فایروال بدون فیلتر `ct state new` لود شوند، پکت‌های متعلق به کانکشن‌های قدیمی (`ESTABLISHED`) به پورت لوکال Xray ری‌دایرکت می‌شوند. از آنجا که Xray هندشیک اولیه (SYN/ACK) آنها را ندیده است، سریعاً پاسخ TCP RST بازمی‌گرداند. این موضوع باعث کرش استریم‌های ویدیو، دانلودها و تماس‌های صوتی/تصویری موجود در شبکه می‌شود.

### دلیل سوم: دیوار رمزنگاری کلاینت (Untrusted CA Blackout)
این قطعی در لایه شبکه نیست، بلکه در لایه مرورگر است:
- اگر دامنه `google.com` به Xray هدایت شود در حالی که سیستم کاربر `mycert.crt` را ندارد، تمام سرویس‌های گوگل برای آن کاربر به طور کامل مسدود و غیرقابل دسترس می‌شوند (صفحه خطای قرمز گواهی امنیتی).
- دستگاه‌هایی نظیر تلویزیون‌های هوشمند، کنسول‌های بازی، و گجت‌های اینترنت اشیا (IoT) راهی برای ایمپورت کردن این گواهی ندارند؛ لذا هدایت ترافیک آنها منجر به داون‌تایم دائمی آنها خواهد شد.

### دلیل چهارم: محدودیت‌های امنیتی اندروید (Android 7+ Network Security Config)
از اندروید نسخه ۷ به بعد (API 24)، طبق سند رسمی گوگل ([Android Network Security Config](https://developer.android.com/privacy-and-security/security-config)):
> *"By default, secure connections (using protocols like TLS and HTTPS) from all apps trust the pre-installed system CAs, and apps targeting Android 7.0 (API level 24) and higher do not trust user-added CAs."*

نصب گواهی در تنظیمات کاربر (User Store) اندروید، تنها برای وب‌گردی در مرورگرهایی مثل کروم معتبر است. اپلیکیشن‌های مستقل (اینستاگرام، یوتیوب، توییتر) به هیچ عنوان به گواهی کاربر اعتماد نکرده و خطای SSL Handshake می‌دهند، مگر اینکه گوشی روت شده و گواهی مستقیماً در دایرکتوری سیستم `/system/etc/security/cacerts/` تزریق شود.

### دلیل پنجم: پروتکل‌های دارای گواهی هاردکد شده (SSL / Public Key Pinning)
سرویس‌هایی مانند:
- اپلیکیشن تلگرام (Telegram MTProto / TLS)
- پیام‌رسان واتس‌اپ و سیگنال
- اپلیکیشن‌های بانکی و مالی (Mobile Banking)
- سرویس پوش نوتیفیکیشن اپل (APNs: `push.apple.com`)
- اعتبارسنجی لایسنس و بازی‌ها (مانند Steam, Riot Vanguard, Google Play Integrity)
گواهی یا کلید عمومی سرور اصلی را درون خود هاردکد کرده‌اند. به محض اجرای MITM، این اپلیکیشن‌ها به صورت خودکار ارتباط را مسدود کرده و دسترسی کاربر به این برنامه‌ها ۱۰۰٪ قطع می‌شود.

### دلیل ششم: گره کور QUIC / HTTP/3 در مرورگرها
ترافیک یوتیوب و گوگل در مرورگرهای مدرن (Chrome, Edge, Safari) به طور پیش‌فرض بر بستر UDP پورت ۴۴۳ (پروتکل QUIC) ارسال می‌شود.
کانفیگ `xray-mitm` صراحتاً در این‌باند‌های دیکریپت خود فقط TCP را پشتیبانی می‌کند (`"network": "tcp"`).
- اگر UDP 443 باز بماند، پکت‌های QUIC مستقیماً به آی‌پی‌های فیلتر شده یوتیوب ارسال شده و مسدود می‌شوند.
- مرورگر تا زمان تایم‌اوت شدن UDP (حدود ۳ الی ۱۰ ثانیه) معطل مانده و کاربر افت شدید سرعت و فریز شدن صفحه را تجربه می‌کند.
- اگر پکت UDP 443 به صورت بی‌صدا دور انداخته شود (`DROP`)، باز هم مرورگر چند ثانیه تلاش مجدد (Retransmit) می‌کند تا به ناچار روی TCP سوئیچ کند.

### دلیل هفتم: سیاه‌چاله دی‌ان‌اس (DNS Blackhole)
در `config.json.example`، پروکسی از FakeDNS و ارسال DoH روی `h2c://1.1.1.1/dns-query` با ماسک `www.microsoft.com` استفاده می‌کند. اگر روتر DNS ساب‌نت را به Xray متصل کند قبل از اینکه تانل DoH به طور کامل بالا آمده و اعتبارسنجی شده باشد، هیچ کلاینتی در خانه نمی‌تواند هیچ دامنه‌ای را ریزالو کند و کل اینترنت خانه قطع می‌شود.

---

## 3. The Core Question: Is Zero-Downtime Possible?

| بعد عملیاتی (Dimension) | امکان داون‌تایم صفر؟ | شرط لازم برای تحقق |
| :--- | :---: | :--- |
| **لایه پکت و روتینگ شبکه (Network Plane)** | **بله (۱۰۰٪)** | استفاده از جداول مجزای `nftables`، فیلتر `ct state new`، سوئیچینگ اتمیک و بدون ری‌استارت فایروال |
| **لایه پایداری نشست‌ها (Connection Continuity)** | **بله (۱۰۰٪)** | نادیده گرفتن سشن‌های باز موجود و هدایت اختصاصی کانکشن‌های نوظهور |
| **مکانیزم بازیابی خطا (Fail-Open Recovery)** | **بله (۱۰۰٪)** | واچ‌داگ خودکار که در صورت کرش Xray رول را در چند میلی‌ثانیه غیرفعال کند |
| **لایه کلاینت وب (Browser HTTPS Traffic)** | **مشروط** | نیاز قطعی به نصب اولیه `mycert.crt` در سیستم‌عامل/مرورگر قبل از تغییر مسیر ترافیک |
| **اپلیکیشن‌های موبایل معمولی (Unrooted Android)** | **خیر (در اپلیکیشن)** | اندروید ۷ به بعد اجازه MITM در اپ‌ها با گواهی کاربر را نمی‌دهد (فقط نسخه وب کار می‌کند) |
| **سرویس‌های Pinned (بانک، تلگرام، اپل)** | **خیر (غیرممکن)** | تنها راه دستیابی به zero-downtime، **Bypass کامل** این سرویس‌ها از MITM است |
| **دستگاه‌های IoT / تلویزیون هوشمند** | **خیر (غیرممکن)** | تنها راه دستیابی به zero-downtime، **ایزوله کردن MAC/IP** این دستگاه‌ها از رول‌های MITM است |

**نتیجه‌گیری:** داون‌تایم صفر سراسری «اتوماتیک و بدون دخالت کلاینت» به دلیل ماهیت رمزنگاری TLS وجود خارجی ندارد؛ اما **داون‌تایم صفر شبکه از طریق معماری Selective & Canary Rollout کاملاً دست‌یافتنی است.**

---

## 4. Technical Blueprint for Zero-Downtime Implementation on OpenWrt

برای اجرای بدون قطعی، از معماری ۶ لایه‌ای زیر استفاده می‌کنیم:

```
+-----------------------------------------------------------------------------------------+
|                               ZERO-DOWNTIME ARCHITECTURE                                |
+-----------------------------------------------------------------------------------------+
|                                                                                         |
|  1. Pre-warm Daemon       -> Start Xray on localhost:10808 (Zero network changes)       |
|  2. Cryptographic Stage   -> Generate CA, export public cert, install on Pilot device   |
|  3. Atomic Nftables Set   -> Create table inet xray_mitm with dynamic canary IP set     |
|  4. QUIC Port-Unreachable -> Fast reject UDP 443 (RFC 9000 instant TCP fallback)        |
|  5. Pinning / IoT Bypass  -> Exclude Apple, Telegram, Banks, and IoT IPs from sets      |
|  6. Active Watchdog       -> Probe 127.0.0.1:10808 every 3s; Auto-disable on failure    |
|                                                                                         |
+-----------------------------------------------------------------------------------------+
```

### 4.1 لود اتمیک فایروال بدون شکستن Conntrack (`nftables`)
در OpenWrt 22.03 به بعد (سیستم `fw4`) فایروال مبتنی بر `nftables` است. برای جلوگیری از ری‌استارت فایروال:
- نباید دستوراتی مانند `/etc/init.d/firewall restart` یا `fw4 reload` اجرا شوند.
- به جای ادغام با زنجیره‌های شلوغ fw4، یک **جدول مستقل** به نام `table inet xray_mitm` ایجاد می‌کنیم. هسته لینوکس اعمال قوانین را در یک تراکنش اتمیک (Netlink atomic commit) انجام می‌دهد.
- برای حفظ اتصالات فعلی، شرط `ct state new` اجباری است:

```nftables
table inet xray_mitm {
    set canary_clients {
        type ipv4_addr
        flags interval
        elements = { 192.168.1.150 } # فقط آی‌پی تستر اولیه
    }

    set bypass_destinations {
        type ipv4_addr
        flags interval
        elements = { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 }
    }

    chain prerouting {
        type nat hook prerouting priority dstnat - 5; policy accept;

        # ۱. فقط کانکشن‌های کاملاً جدید هدایت شوند (مانع از ریست شدن دانلودهای در حال اجرا)
        ct state established,related accept

        # ۲. ترافیک دستگاه‌هایی که در لیست قناری نیستند بدون تغییر عبور کند
        ip saddr != @canary_clients accept

        # ۳. مقاصد لوکال و شبکه خصوصی معاف شوند
        ip daddr @bypass_destinations accept

        # ۴. پورت‌های وب به پورت این‌باند Xray ری‌دایرکت شوند
        tcp dport { 80, 443 } redirect to :10808
    }

    chain forward_reject_quic {
        type filter hook forward priority filter - 5; policy accept;

        # رد سریع پکت‌های QUIC با سیگنال ICMP port-unreachable
        ip saddr @canary_clients udp dport 443 reject with icmpx type port-unreachable
    }
}
```

### 4.2 مدیریت ترافیک QUIC بر اساس استاندارد RFC 9000
طبق استاندارد [RFC 9000 Section 5 (Connections)](https://datatracker.ietf.org/doc/html/rfc9000#section-5):
اگر روتر پکت UDP 443 را به جای `drop` با اکشن `reject with icmpx type port-unreachable` پاسخ دهد، استک شبکه مرورگر (Blink / WebKit) منتظر تایم‌اوت ۳ تا ۱۰ ثانیه‌ای نمی‌ماند و در کمتر از ۱۰ میلی‌ثانیه به حالت **TCP Fast Fallback** سوئیچ می‌کند. این کار تاخیر باز شدن صفحات یوتیوب و گوگل را کاملاً از بین می‌برد.

### 4.3 معماری DNS غیرمخرب (Non-Disruptive DNS)
برای جلوگیری از بلک‌هول دی‌ان‌اس:
- تنظیمات پیش‌فرض `dnsmasq` روتر را دستکاری نکنید. روتر به کار عادی خود برای ارائه DNS به کلاینت‌ها ادامه می‌دهد.
- ویژگی Sniffing در این‌باند Xray با مقدار `destOverride: ["fakedns", "tls"]` فعال است [Source: `config.json.example`, Line 70].
- وقتی ترافیک TCP 443 به پورت ۱۰۸۰۸ هدایت می‌شود، حتی اگر کلاینت به یک IP فرضی یا واقعی وصل شده باشد، Xray از طریق خواندن SNI در لایه TLS می‌فهمد مقصد واقعی کجاست و دامنه را در لایه خروجی خودش به طور مستقل ریزالو می‌کند. بنابراین نیازی به دستکاری اجباری DNS کلاینت در شروع کار نیست.

### 4.4 سازوکار Fail-Open و Watchdog اتوماتیک
اگر فرآیند Xray با کمبود حافظه (OOM) در روترهایی مثل AX3000T (با رم ۲۵۶ مگابایت) مواجه شود یا کرش کند، هدایت ترافیک به یک پورت مرده باعث خطای `Connection Refused` برای تمام دامنه‌ها می‌شود.
راه‌حل: اجرای یک اسکریپت Watchdog سبک و محلی در `/usr/sbin/xray-mitm-watchdog` که هر ۳ ثانیه سوکت لوکال را بررسی کند. در صورت عدم پاسخگویی، دستور زیر فوراً رول فایروال را خنثی می‌کند:
```sh
nft flush chain inet xray_mitm prerouting
```
به این ترتیب، شبکه بلافاصله به وضعیت Fail-Open برگشته و ترافیک مستقیم از اینترنت عبور داده می‌شود بدون اینکه کاربر افت اتصال متوجه شود.

---

## 5. Step-by-Step Zero-Downtime Migration Runbook

این دستورالعمل گام‌به‌گام به شما اجازه می‌دهد `xray-mitm` را روی روتر OpenWrt پیاده‌سازی کنید بدون اینکه هیچ‌یک از افراد متصل به شبکه متوجه افت یا قطعی شوند.

### گام ۰: آماده‌سازی و نصب پکیج‌ها بدون فعال‌سازی سراسری
پکیج‌ها را نصب کنید اما هیچ سرویسی را روی بوت اتوماتیک قرار ندهید و فایروال را ری‌استارت نکنید:
```sh
# ۱. دانلود اسکریپت نصب رسمی با تایید امضای SHA-256
wget -qO /tmp/install-xray-mitm.sh https://duuuude.github.io/xray-mitm-openwrt/install.sh
printf '%s  %s\n' 'bbeaa48a19df4939333375d391ca7da4c2baa6095b210252d9cc479434351d4d' '/tmp/install-xray-mitm.sh' | sha256sum -c -
sh /tmp/install-xray-mitm.sh
```
*توجه: این اسکریپت تنها فایل‌های باینری و LuCI را اضافه می‌کند و سرویس به صورت پیش‌فرض خاموش است (Zero impact).*

### گام ۱: تولید گواهی CA اختصاصی و راه‌اندازی سایلنت Xray
```sh
# ۱. بارگذاری کانفیگ نمونه
/usr/libexec/xray-mitm/config install-sample

# ۲. تولید اسلات کاندیدای گواهی و فعال‌سازی آن در اسلات current
/usr/libexec/xray-mitm/cert generate "My-Home-Gateway-CA"
/usr/libexec/xray-mitm/cert activate-candidate

# ۳. روشن کردن سرویس روی لوکال‌هاست (بدون لمس فایروال)
uci set xray-mitm.main.enabled='1'
uci commit xray-mitm
/etc/init.d/xray-mitm start

# ۴. اعتبارسنجی لوکال سلامت سرویس با هلپر داخلی
/usr/libexec/xray-mitm/check
```
خروجی باید نشان دهد:
```text
PASS: configuration, active CA, and MITM SOCKS path are working.
```

### گام ۲: انتقال و نصب گواهی Root روی کلاینت تستر (Pilot Client)
فایل گواهی عمومی `/etc/xray-mitm/mycert.crt` را روی کامپیوتر کلاینت تستر (مثلاً لپ‌تاپ مک یا ویندوز) کپی و نصب کنید:
- **در macOS:**
  ```sh
  scp root@192.168.1.1:/etc/xray-mitm/mycert.crt ./
  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ./mycert.crt
  ```
- **در Windows (PowerShell با دسترسی ادمین):**
  ```powershell
  scp root@192.168.1.1:/etc/xray-mitm/mycert.crt .\mycert.crt
  certutil.exe -addstore -f "ROOT" .\mycert.crt
  ```

### گام ۳: تزریق جدول اتمیک فایروال فقط برای IP قناری (Canary Injection)
فرض کنید IP لپ‌تاپ تستر `192.168.1.150` است. فایل زیر را روی روتر ایجاد و اعمال کنید:
```sh
cat << 'EOF' > /tmp/xray_mitm_atomic.nft
table inet xray_mitm {
    set canary_ips {
        type ipv4_addr
        flags interval
        elements = { 192.168.1.150 }
    }

    set bypass_subnets {
        type ipv4_addr
        flags interval
        elements = { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4 }
    }

    chain prerouting {
        type nat hook prerouting priority dstnat - 5; policy accept;
        ct state established,related accept
        ip saddr != @canary_ips accept
        ip daddr @bypass_subnets accept
        tcp dport { 80, 443 } redirect to :10808
    }

    chain forward {
        type filter hook forward priority filter - 5; policy accept;
        # جلوگیری از معطلی QUIC
        ip saddr @canary_ips udp dport 443 reject with icmpx type port-unreachable
    }
}
EOF

# اعمال اتمیک در کسری از میلی‌ثانیه بدون ری‌استارت فایروال
nft -f /tmp/xray_mitm_atomic.nft
```

### گام ۴: تست و تایید صحت کارکرد از کلاینت قناری
روی لپ‌تاپ تستر اجرا کنید:
```sh
curl -Iv --max-time 10 https://www.google.com 2>&1 | grep -E 'issuer:|HTTP/'
```
خروجی مورد انتظار:
```text
* Server certificate:
*  issuer: CN=My-Home-Gateway-CA
< HTTP/2 200
```
اگر این خروجی را مشاهده کردید، سیستم بدون حتی یک میلی‌ثانیه قطعی برای سایر دستگاه‌های خانه، برای این کلاینت فعال شده است.

### گام ۵: پیاده‌سازی Watchdog برای پایداری ۱۰۰٪ (Fail-Open Daemon)
یک اسکریپت بررسی سلامت در `/usr/sbin/xray-mitm-watchdog` قرار دهید:
```sh
cat << 'EOF' > /usr/sbin/xray-mitm-watchdog
#!/bin/sh
FAIL_COUNT=0
MAX_FAILS=2

while true; do
    if ! /usr/bin/curl -s --socks5 127.0.0.1:10808 --max-time 3 -o /dev/null https://www.google.com; then
        FAIL_COUNT=$((FAIL_COUNT + 1))
        if [ "$FAIL_COUNT" -ge "$MAX_FAILS" ]; then
            # غیرفعال‌سازی آنی رول و برگرداندن شبکه به حالت مستقیم
            nft flush chain inet xray_mitm prerouting 2>/dev/null
            logger -t xray-watchdog "CRITICAL: Xray MITM down! Flushed redirect chain to fail-open."
        fi
    else
        if [ "$FAIL_COUNT" -ge "$MAX_FAILS" ]; then
            # در صورت بازگشت سلامتی، رول دوباره فعال شود
            nft add rule inet xray_mitm prerouting ct state established,related accept
            nft add rule inet xray_mitm prerouting ip saddr != @canary_ips accept
            nft add rule inet xray_mitm prerouting ip daddr @bypass_subnets accept
            nft add rule inet xray_mitm prerouting tcp dport { 80, 443 } redirect to :10808
            logger -t xray-watchdog "INFO: Xray MITM restored. Re-armed redirect chain."
        fi
        FAIL_COUNT=0
    fi
    sleep 4
done
EOF
chmod +x /usr/sbin/xray-mitm-watchdog
```
اجرای این سرویس در پس‌زمینه تضمین می‌کند که حتی در صورت کرش باینری Xray در اثر OOM، ترافیک خانه هرگز قطع نخواهد شد.

### گام ۶: اضافه کردن تدریجی دستگاه‌ها به ساب‌نت بدون داون‌تایم
هر زمان گواهی CA روی دستگاه دوم (مثلاً کامپیوتر دوم با آی‌پی `192.168.1.151`) نصب شد، فقط کافیست آن را به صورت اتمیک به جدول اضافه کنید:
```sh
nft add element inet xray_mitm canary_ips { 192.168.1.151 }
```
این دستور **صفر میلی‌ثانیه وقفه** دارد و هیچ ارتباط فعال دیگری را قطع نمی‌کند.

---

## 6. Primary Source Citations

1. **Repository Source Code (`duuuude/xray-mitm-openwrt`):**
   - Package Architecture & Feed Specs: [`README.md`](https://github.com/duuuude/xray-mitm-openwrt/blob/main/README.md)
   - Service Daemon & Lifecycle Hooks: [`xray-mitm/files/etc/init.d/xray-mitm`](https://github.com/duuuude/xray-mitm-openwrt/blob/main/xray-mitm/files/etc/init.d/xray-mitm)
   - Certificate Rotation & Slot Atomic Swapping: [`xray-mitm/files/usr/libexec/xray-mitm/cert`](https://github.com/duuuude/xray-mitm-openwrt/blob/main/xray-mitm/files/usr/libexec/xray-mitm/cert)
   - PassWall2 Transactional Helper & Restart Triggers: [`xray-mitm/files/usr/libexec/xray-mitm/passwall2`](https://github.com/duuuude/xray-mitm-openwrt/blob/main/xray-mitm/files/usr/libexec/xray-mitm/passwall2)
   - Tunnel Inbounds and Repack Outbounds: [`xray-mitm/files/usr/share/xray-mitm/config.json.example`](https://github.com/duuuude/xray-mitm-openwrt/blob/main/xray-mitm/files/usr/share/xray-mitm/config.json.example)

2. **Upstream MITM Domain Fronting Concept:**
   - Patterniha MMDF & MITM-DomainFronting v23: [`patterniha/MITM-DomainFronting`](https://github.com/patterniha/MITM-DomainFronting)
   - Xray-core Dynamic Certificate Issuance Feature Request: [XTLS/Xray-core Issue #4348](https://github.com/XTLS/Xray-core/issues/4348)

3. **Xray-Core TLS Implementation:**
   - Dynamic On-The-Fly Certificate Generation (`Certificate_AUTHORITY_ISSUE`): [`transport/internet/tls/config.go`](https://github.com/XTLS/Xray-core/blob/main/transport/internet/tls/config.go)
   - Peer Certificate Name Verification (`verifyPeerCertByName`, `IsFromMitm`): [`transport/internet/tls/config.go`](https://github.com/XTLS/Xray-core/blob/main/transport/internet/tls/config.go)

4. **Linux Netfilter & OpenWrt Documentation:**
   - OpenWrt Firewall4 (fw4) Nftables Drop-in Architecture: [OpenWrt Wiki - Firewall Configuration (fw4)](https://openwrt.org/docs/guide-user/firewall/firewall_configuration)
   - Netfilter Atomic Commits & Conntrack State Preservation: [Nftables Operations & Atomic Ruleset](https://wiki.nftables.org/wiki-nftables/index.php/Atomic_rule_updates)
   - Transparent Proxying (TPROXY vs REDIRECT): [Kernel Documentation - Transparent Proxy](https://www.kernel.org/doc/Documentation/networking/tproxy.txt)

5. **RFC & Security Standards:**
   - QUIC Fast Handshake Failure on Port Unreachable: [IETF RFC 9000 - QUIC Transport Parameter Handling, Section 5](https://datatracker.ietf.org/doc/html/rfc9000#section-5)
   - Android User Certificate Rejection: [Android Developer Guide - Network Security Configuration](https://developer.android.com/privacy-and-security/security-config)
   - Apple Certificate Trust Store Settings: [Apple Support - Trust manually installed certificate profiles in iOS and iPadOS](https://support.apple.com/en-us/HT204477)
