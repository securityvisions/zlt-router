// mock-server.mjs — local demo server for the Xirouter NOC dashboard.
//
// Serves the built SPA from web/dist/ and answers the Router API endpoints
// (/cgi-bin/routerapi.sh/*) with realistic fixture data, so the dashboard can
// be seen in a browser without touching the real router. Any non-empty token
// passes the Setup screen.
//
// Usage:  node mock-server.mjs   (from web/, after `npm run build`)
// Then open http://localhost:4174

import http from 'node:http';
import { readFileSync, existsSync, statSync } from 'node:fs';
import { join, dirname, extname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DIST = join(__dirname, 'dist');
const PORT = process.env.PORT || 4174;

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
  '.json': 'application/json; charset=utf-8',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
};

// ---- fixture data (shapes match the real Router API) ----
const now = Math.floor(Date.now() / 1000);
const H = 3600;

const events = [
  { epoch: now - 4 * 60, category: 'internet', severity: 'info', kind: 'internet_up', actor: 'passwall-autorecover', message: 'PassWall restarted; VPN routing restored' },
  { epoch: now - 26 * 60, category: 'internet', severity: 'critical', kind: 'internet_down', actor: 'passwall-health', message: 'fail-open: PassWall disabled; direct internet' },
  { epoch: now - 3 * H, category: 'internet', severity: 'warning', kind: 'node_rotated', actor: 'passwall-health', message: 'node cdn_ws -> eFCgnGrZ' },
  { epoch: now - 5 * H, category: 'device', severity: 'info', kind: 'device_joined', actor: '96:04:e1:00:00:00', message: 'iPhone (192.168.1.50)' },
  { epoch: now - 8 * H, category: 'security', severity: 'warning', kind: 'dns_unhealthy', actor: 'dns-stats', message: 'DNS unhealthy: success=0.97 latency=240ms' },
  { epoch: now - 14 * H, category: 'device', severity: 'info', kind: 'device_approved', actor: 'aa:bb:cc:dd:ee:01', message: 'quarantine: device approved' },
  { epoch: now - 22 * H, category: 'proxy', severity: 'info', kind: 'proxy_changed', actor: 'router-api', message: 'proxy switched to hysteria2' },
  { epoch: now - 26 * H, category: 'package', severity: 'warning', kind: 'package_threshold', actor: 'forecast', message: 'projected 342000 Toman at/over 300000 budget' },
  { epoch: now - 30 * H, category: 'internet', severity: 'warning', kind: 'operator_reselected', actor: 'x28watch', message: 'X28 drifted off MCI; re-selecting' },
  { epoch: now - 2 * 24 * H, category: 'internet', severity: 'warning', kind: 'quality_degraded', actor: 'passwall-health', message: 'active node at 6.5 Mbps (floor 10)' },
  { epoch: now - 2 * 24 * H + 30 * 60, category: 'internet', severity: 'info', kind: 'quality_recovered', actor: 'passwall-health', message: 'link quality recovered (sample=13.2 Mbps)' },
];

const qualityPoints = [];
for (let i = 23; i >= 0; i--) {
  const base = 2 + Math.sin((24 - i) / 4) * 1.5;
  qualityPoints.push({
    ts: new Date((now - i * H) * 1000).toISOString().slice(0, 16).replace('T', ' '),
    latency_s: +(0.25 + Math.abs(Math.sin((24 - i) / 3)) * 0.15).toFixed(2),
    passive_mbps: +(base + (i === 9 ? -3 : 0)).toFixed(2),
    node: i % 5 === 2 ? 'hyst_vps' : 'cdn_ws',
  });
}

const api = {
  '/cgi-bin/routerapi.sh/health': {
    score: 88,
    band: 'Good',
    as_of_unix: now,
    components: [
      { name: 'link_quality', weight: 30, penalty: 0, detail: 'OK' },
      { name: 'proxy', weight: 20, penalty: 0, detail: 'up' },
      { name: 'services', weight: 20, penalty: 5, detail: 'nlbwmon' },
      { name: 'freshness', weight: 15, penalty: 0, detail: '120s' },
      { name: 'dns', weight: 15, penalty: 0, detail: 'success=0.9900 latency=48ms' },
    ],
  },
  '/cgi-bin/routerapi.sh/status': {
    uptime: '3 days, 4:12',
    load: '0.10',
    ram: { used_mb: 412, total_mb: 944 },
    temp_c: 48,
    disk: { pct: 68, free: '3.1G' },
    proxy: { state: 'up', latency_s: 0.31, node: 'REALITY-443-parsa' },
  },
  '/cgi-bin/routerapi.sh/link': {
    operator: 'IR - MCI Wap',
    tech: '5G(NSA)',
    signal: 4,
    rsrp: -77,
    rsrp_5g: -92,
    band: '',
    plmn: '43211',
    flow: { dl: 3441.61, ul: 243.88 },
  },
  '/cgi-bin/routerapi.sh/quality': { hours: 24, points: qualityPoints },
  '/cgi-bin/routerapi.sh/events': { events },
};

// Parse query string so endpoints behave like the real ones.
function parseQuery(url) {
  const i = url.indexOf('?');
  const out = {};
  if (i === -1) return out;
  for (const kv of url.slice(i + 1).split('&')) {
    const [k, v] = kv.split('=');
    out[decodeURIComponent(k)] = decodeURIComponent(v ?? '');
  }
  return out;
}

const server = http.createServer((req, res) => {
  const urlPath = req.url.split('?')[0];

  if (urlPath.startsWith('/cgi-bin/routerapi.sh/')) {
    const key = urlPath.includes('/events') || urlPath.includes('/quality')
      ? urlPath.split('/cgi-bin/routerapi.sh/')[1].split('?')[0]
      : urlPath;
    const q = parseQuery(req.url);
    let body = api[urlPath] ?? api[`/cgi-bin/routerapi.sh/${key}`];

    if (urlPath.endsWith('/events')) {
      const limit = +(q.limit ?? 50);
      const category = q.category ?? '';
      const list = category
        ? events.filter((e) => e.category === category)
        : events;
      body = { events: list.slice(0, limit) };
    }
    if (urlPath.endsWith('/quality')) {
      const hours = +(q.hours ?? 24);
      body = { hours, points: qualityPoints.slice(-hours) };
    }

    if (!body) {
      res.writeHead(404, { 'Content-Type': 'application/json' });
      res.end('{"error":"unknown endpoint"}');
      return;
    }
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(body));
    return;
  }

  // Static files from dist; SPA fallback to index.html.
  let file = join(DIST, urlPath === '/' ? 'index.html' : urlPath);
  if (!existsSync(file) || !statSync(file).isFile()) {
    file = join(DIST, 'index.html');
  }
  const type = MIME[extname(file)] ?? 'application/octet-stream';
  res.writeHead(200, { 'Content-Type': type });
  res.end(readFileSync(file));
});

server.listen(PORT, () => {
  console.log(`Xirouter NOC demo: http://localhost:${PORT}`);
  console.log('Any non-empty token passes the Setup screen (e.g. "demo").');
});
