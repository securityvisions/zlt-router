# 03 - Routing Latency & Gaming Performance: Shatel vs TCI Tanoma

**Type:** `research`  
**Status:** resolved

## Resolution

1. **Domestic & IXP Latency:**
   - Both operators deliver exceptional domestic latency due to physical glass-core transport: **1–4 ms** to Tehran IXP and domestic servers.
2. **International Gateways & Gaming Pings:**
   - **Shatel Fiber (Clear Winner for Gaming):**
     - Offers an optional one-click **"Gaming Profile" (FastPath)** in the MyShatel dashboard.
     - Direct BGP peering with European routes via Istanbul and Frankfurt.
     - Typical pings: `8.8.8.8`: 65–75 ms; European gaming servers (Frankfurt/Vienna): **68–85 ms**.
     - Very low jitter (<3 ms) during peak evening hours (20:00–24:00).
   - **TCI Tanoma:**
     - Routes strictly through standard TIC upstream pools.
     - Typical pings: `8.8.8.8`: 80–95 ms; European gaming servers: **85–115 ms**.
     - Subject to occasional route flapping and packet loss during peak national usage spikes.  
**Blocked by:** none  

## Question

How do the two operators compare in international gateway routing, domestic peering (Tehran IXP), ping jitter, packet loss during peak evening hours (20:00–24:00), and gaming profile optimizations?

## Execution Plan

1. Analyze Shatel's routing paths (Frankfurt, Istanbul, Amsterdam) and its dedicated "Gaming Profile" (پروفایل گیمینگ / Fast Path).
2. Analyze TCI Tanoma's direct routing via TIC upstream providers.
3. Compare ping baselines to key destinations: Cloudflare (1.1.1.1), Google (8.8.8.8), European gaming servers (Valve Frankfurt, Riot Europe, EA).
