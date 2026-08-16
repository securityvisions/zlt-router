// Xirouter NOC — Router API client.
//
// The dashboard talks to the same-origin Router API (uhttpd CGI) with the
// standard Basic auth header (username fixed `xirouter`, the token is the
// password) — the contract the Android app already uses.

export interface HealthComponent {
  name: string;
  weight: number;
  penalty: number;
  detail: string;
}

export interface Health {
  score: number;
  band: 'Excellent' | 'Good' | 'Degraded' | 'Poor';
  as_of_unix: number;
  components: HealthComponent[];
}

export interface NetworkEvent {
  epoch: number;
  category: string;
  severity: 'info' | 'warning' | 'critical';
  kind: string;
  actor: string;
  message: string;
}

export interface EventsResponse {
  events: NetworkEvent[];
}

export interface QualityPoint {
  ts: string;
  latency_s: number;
  passive_mbps: number;
  node: string;
}

export interface QualityResponse {
  hours: number;
  points: QualityPoint[];
}

export interface LinkState {
  operator: string;
  tech: string;
  signal: number | null;
  rsrp: number | null;
  rsrp_5g: number | null;
  band: string;
  plmn: string;
  flow: { dl: number | null; ul: number | null };
}

export interface Status {
  uptime: string;
  load: string;
  ram: { used_mb: number; total_mb: number };
  temp_c: number | null;
  disk: { pct: number; free: string };
  proxy: { state: 'up' | 'down'; latency_s: number; node: string };
}

const TOKEN_KEY = 'xirouter.noc.token';

export function getToken(): string {
  return localStorage.getItem(TOKEN_KEY) ?? '';
}

export function setToken(token: string): void {
  localStorage.setItem(TOKEN_KEY, token);
}

export function clearToken(): void {
  localStorage.removeItem(TOKEN_KEY);
}

export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

async function request<T>(path: string, token: string): Promise<T> {
  const headers = new Headers();
  if (token) headers.set('Authorization', `Basic ${btoa(`xirouter:${token}`)}`);
  const res = await fetch(`/cgi-bin/routerapi.sh${path}`, { headers });
  if (res.status === 401) throw new ApiError(401, 'unauthorized');
  if (!res.ok) throw new ApiError(res.status, `HTTP ${res.status}`);
  return (await res.json()) as T;
}

export function api(token: string) {
  return {
    health: () => request<Health>('/health', token),
    events: (limit = 30, category = '') =>
      request<EventsResponse>(
        `/events?limit=${limit}${category ? `&category=${encodeURIComponent(category)}` : ''}`,
        token,
      ),
    quality: (hours = 24) => request<QualityResponse>(`/quality?hours=${hours}`, token),
    link: () => request<LinkState>('/link', token),
    status: () => request<Status>('/status', token),
  };
}
