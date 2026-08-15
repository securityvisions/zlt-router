# Xirouter — Router API contract

The seam between the router (server) and the Xirouter Android app (client). The server
implementation lives in `~/home-network/router/` (canonical copies of the deployed scripts);
this file is the client's copy of the contract. When one side changes, update both.

## Base & auth

- Base URL: `http://192.168.1.1/cgi-bin/routerapi.sh` (LAN). Overridable in the app's setup.
- Every request must carry `Authorization: Basic base64(xirouter:<token>)` — the token is the
  Basic password, the username is fixed `xirouter`. (uhttpd does not forward custom `X-*`
  headers to CGI, so a plain header token is impossible; Basic auth rides the standard
  Authorization header.) The token lives in a root-only config file on the router. A
  missing/wrong token returns `401` with `{"error":"unauthorized"}`.
- The CGI dispatcher reads the HTTP method; `POST` bodies are JSON (`Content-Type: application/json`).
- All responses are `application/json`; every value is plain ASCII digits (no Persian digits on
  the wire — the app localizes). GB values are decimal floats. Toman values are integers.

## Endpoints

### `GET /status`

```json
{
  "uptime": "3 days, 4:12",
  "load": "0.10",
  "ram": { "used_mb": 412, "total_mb": 944 },
  "temp_c": 48,
  "disk": { "pct": 68, "free": "3.1G" },
  "proxy": { "state": "up", "latency_s": 0.31, "node": "REALITY-443-parsa" }
}
```

`proxy.state` is `up`/`down`; `proxy.node` names the active PassWall node (`REALITY-443-parsa`
default, `hysteria2` when switched).

### `GET /link`

The X28 cellular link state (the WAN edge):

```json
{
  "operator": "IR - MCI Wap",
  "tech": "5G(NSA)",
  "signal": 4,
  "rsrp": -77,
  "rsrp_5g": -92,
  "band": "",
  "plmn": "43211",
  "flow": { "dl": 3441.61, "ul": 243.88 }
}
```

`operator`/`tech`/`band`/`plmn` are strings (`band` is empty on this firmware —
not exposed); `signal` is the vendor 0–5 level; `rsrp`/`rsrp_5g`/`flow.*` are
numbers or `null` when not reported. 500 with `{"error":"link unavailable"}`
when the X28 link reader can't reach the device.

### `GET /usage?period=today|month`

```json
{ "period": "today", "rows": [ { "name": "iPhone", "mac": "aa:bb:cc:dd:ee:ff", "gb": 1.234 } ] }
```

`period=month` reads the current month's log. Rows are sorted by GB descending; the router's own
interfaces are excluded.

### `GET /cost?friday=yes|no`

```json
{
  "friday": false, "rate_full": 7700, "rate_friday": 4620,
  "rows": [ { "name": "iPhone", "gb": 1.234, "toman": 12000, "share": 32.5 } ],
  "total_gb": 3.8, "total_toman": 37000
}
```

`share` is the device's percent of the total. `toman` already applies the chosen rate and
rounds to the nearest 1,000. `total_toman` is the sum of the rounded rows.

### `GET /bill?friday=yes|no&month=YYYY-MM`

Same shape as `/cost`, for the given month (defaults to the current month).

### `GET /balance`

```json
{
  "cached": true,
  "as_of_unix": 1789000000,
  "data_plan": {
    "provider": "Samantel",
    "subscriber": "989121234567",
    "quota_gb": 200.0,
    "remain_gb": 146.5,
    "consumed_gb": 53.5,
    "activation": "2026-07-01",
    "expiry": "2027-08-05",
    "status": "active",
    "freshness": { "as_of_unix": 1789000000, "source": "samantel_remain" }
  },
  "packages": [
    {
      "id": "samantel:4815",
      "provider": "Samantel",
      "subscriber": "989121234567",
      "type": "Bonus",
      "name": "Benefit Data - Summer Bonus",
      "category": "data",
      "window": "monthly",
      "quota_gb": 50.0,
      "remain_gb": 16.5,
      "consumed_gb": 33.5,
      "activation": "2026-07-01",
      "expiry": "2026-09-01",
      "status": "active",
      "priority": 2,
      "freshness": { "as_of_unix": 1789000000, "source": "samantel_remain" }
    }
  ],
  "total_gb": 146.5,
  "plans": 2,
  "main": { "quota": 150, "remain": 130.0, "pct": 86, "expires": "2027-08-05", "days": 363 },
  "expired": 1,
  "drain": "~3.5 GB/day → ~41d left",
  "series": [ { "date": "2026-08-01", "gb": 150.0 } ]
}
```

`data_plan` is the account-level aggregate; quota/remain/consumed are sums of all returned
Packages. `packages` contains every matching ISP package, not only the main Package. `type` and
`name` are verbatim ISP values. `category` and `window` are normalized hints and may be `null`.
Dates are `YYYY-MM-DD` or `null`. `status` preserves the ISP status when supplied, otherwise the
router derives `active`/`depleted`; `priority` preserves the ISP order when supplied, otherwise
it is `0`. Each Package repeats provider/subscriber and freshness so it remains independently
cacheable.

Package `id` is opaque and stable. The router uses an ISP-issued Package identifier where one is
present and persists it as `samantel:<issued-id>`. Existing Packages without an issued identifier
receive a persisted `samantel:migration:<opaque>` ID from a one-time fingerprint mapping; clients
must never derive identity from package fields.

`total_gb`, `plans`, `main`, `expired`, `drain`, and `series` are temporary legacy fields retained
for current app compatibility. `series` is daily balance history, newest first. With no cache the
shape is `{ "cached": false, "as_of_unix": 0, "data_plan": null, "packages": [] }`.

### `GET /clients`

```json
{ "clients": [ { "mac": "aa:bb:cc:dd:ee:ff", "ip": "192.168.1.5", "name": "iPhone", "hostname": "", "today_gb": 1.2 } ] }
```

`name` is the user-set name, else the DHCP hostname, else `Unknown-<mac-prefix>`; `hostname` is
the DHCP hostname if any (a client's `name` may equal its `hostname` when no custom name is set).

### `GET /live`

```json
{
  "ts": 1789e6,
  "wan": { "rx_bytes": 1234567, "tx_bytes": 7654321 },
  "devices": [ { "mac": "aa:bb:cc:dd:ee:ff", "rx_bytes": 1000, "tx_bytes": 500 } ]
}
```

Cumulative byte counters — the app diffs two samples ~1 s apart to compute throughput. The
router's own interfaces are excluded from `devices`.

### `GET /history?kind=balance|usage&days=N`

```json
{ "kind": "usage", "points": [ { "ts": "2026-08-11 07:00", "value": 12.3 } ] }
```

`kind=usage` returns the hourly telemetry series (cumulative total GB at each hour). `kind=balance`
returns the daily balance series. `days` limits the window (default 30). Points oldest-first.

### `GET /devices`

```json
{ "devices": [ { "mac": "aa:bb:cc:dd:ee:ff", "name": "iPhone", "source": "user-names", "watched": true, "today_gb": 1.2 } ] }
```

`source` is `user-names` (custom) or `lease` (from the DHCP hostname) or `default` (Unknown-...).
Known devices = anything with a name or custom watch state.

### `POST /device/rename` — body `{ "mac": "...", "name": "..." }`

Writes the same user-names file the bot reads. `name` must be letters/digits/space/`_-.`, max 24.
Returns `{ "ok": true, "mac": "...", "name": "..." }` or `{ "error": "..." }`.

### `POST /device/watch` — body `{ "mac": "...", "on": true }`

Adds/removes the MAC in the watchlist (same file the bot uses). Returns `{ "ok": true, "watched": true }`.

### `POST /friday` — body `{ "friday": true }`

Sets `LAST_FRIDAY` in the billing config so the bot's scheduled reports agree. Returns
`{ "ok": true, "friday": true }`.

### `POST /test` — body `{ "url": "https://google.com" }`

HTTP status + latency + remote IP from the router, exactly like the bot's `/test`. Returns
`{ "ok": true, "url": "...", "result": "HTTP 200 in 0.31s (IP 1.2.3.4)" }`.

### `POST /proxy/switch` — body `{ "node": "hysteria2" }`

Switches PassWall's global TCP node (the documented `uci set passwall ... && restart`). Only
known nodes are accepted (`REALITY-443-parsa`, `hysteria2`). Returns `{ "ok": true, "node": "..." }`.

### `POST /reboot` — body `{}`

Reboots the router. Guarded by token; the app additionally confirms and requires the lock.
Returns `{ "ok": true }` before the reboot lands.

## Error shape

All errors: `{ "error": "<message>" }` with an appropriate HTTP status (`401` auth, `400` bad
input, `404` unknown endpoint, `500` internal).
