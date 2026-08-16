import { api } from '../api';
import { usePoll } from '../usePoll';

// The quick status strip: proxy state, link state, load/temp, disk, freshness.
// Reads /status (the shared Router API surface).
export function StatusStrip({ token }: { token: string }) {
  const { data, error } = usePoll(() => api(token).status(), 15000, [token]);

  const rows: { label: string; value: string; ok: boolean }[] = [];
  if (data) {
    rows.push(
      {
        label: 'پروکسی',
        value: data.proxy.state === 'up' ? `UP · ${data.proxy.node}` : 'DOWN',
        ok: data.proxy.state === 'up',
      },
      { label: 'رام', value: `${data.ram.used_mb}/${data.ram.total_mb} MB`, ok: true },
      { label: 'دما', value: `${data.temp_c ?? '—'}°C`, ok: (data.temp_c ?? 0) < 70 },
      { label: 'دیسک', value: `${data.disk.pct}% (${data.disk.free})`, ok: (data.disk.pct ?? 0) < 90 },
      { label: 'آپتایم', value: data.uptime, ok: true },
    );
  }

  return (
    <section className="card flex h-full flex-col">
      <h2 className="card-title mb-3">وضعیت</h2>
      {error && <p className="mb-2 text-2xs text-down">خطا: {error}</p>}
      {rows.length === 0 && !error ? <p className="text-xs text-muted">در حال بارگذاری…</p> : null}
      <ul className="mt-auto space-y-2">
        {rows.map((row) => (
          <li key={row.label} className="flex items-center justify-between text-xs">
            <span className="text-muted">{row.label}</span>
            <span className="flex items-center gap-2">
              <span
                className="inline-block h-2 w-2 rounded-full"
                style={{ background: row.ok ? '#22c55e' : '#ef4444' }}
                aria-hidden
              />
              <span className="mono" dir="ltr">
                {row.value}
              </span>
            </span>
          </li>
        ))}
      </ul>
    </section>
  );
}
