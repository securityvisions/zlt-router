import { describe, it, expect, beforeEach, vi } from 'vitest';
import { api, getToken, setToken, clearToken } from '../src/api';

describe('api client', () => {
  beforeEach(() => {
    localStorage.clear();
    vi.restoreAllMocks();
  });

  it('stores the token in localStorage', () => {
    setToken('secret');
    expect(getToken()).toBe('secret');
    clearToken();
    expect(getToken()).toBe('');
  });

  it('sends Basic auth and parses /health', async () => {
    setToken('tok');
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ score: 88, band: 'Good', as_of_unix: 0, components: [] }),
    });
    vi.stubGlobal('fetch', fetchMock);

    const health = await api('tok').health();
    expect(health.score).toBe(88);
    expect(health.band).toBe('Good');

    const [url, opts] = fetchMock.mock.calls[0];
    expect(url).toBe('/cgi-bin/routerapi.sh/health');
    expect(opts.headers.get('Authorization')).toBe(`Basic ${btoa('xirouter:tok')}`);
  });

  it('throws ApiError(401) on unauthorized', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({ ok: false, status: 401, json: async () => ({}) }),
    );
    await expect(api('bad').health()).rejects.toMatchObject({ status: 401 });
  });

  it('builds the events query with category filter', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue({ ok: true, status: 200, json: async () => ({ events: [] }) });
    vi.stubGlobal('fetch', fetchMock);
    await api('tok').events(20, 'internet');
    expect(fetchMock.mock.calls[0][0]).toBe('/cgi-bin/routerapi.sh/events?limit=20&category=internet');
  });
});
