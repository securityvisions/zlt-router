import { useState } from 'react';
import { api } from '../api';
import { usePoll } from '../usePoll';

const CATEGORY_LABELS: Record<string, string> = {
  internet: 'اینترنت',
  device: 'دستگاه',
  proxy: 'پروکسی',
  package: 'بسته',
  router: 'روتر',
  security: 'امنیت',
};

const SEVERITY_COLORS: Record<string, string> = {
  info: '#3b82f6',
  warning: '#f59e0b',
  critical: '#ef4444',
};

function timeAgo(epoch: number): string {
  const s = Math.floor(Date.now() / 1000) - epoch;
  if (s < 0) return 'همین الان';
  if (s < 60) return `${s} ثانیه پیش`;
  if (s < 3600) return `${Math.floor(s / 60)} دقیقه پیش`;
  if (s < 86400) return `${Math.floor(s / 3600)} ساعت پیش`;
  return `${Math.floor(s / 86400)} روز پیش`;
}

// The Network Event feed: newest-first, severity-colored, with a category
// filter. Polls /events.
export function EventsFeed({ token }: { token: string }) {
  const [category, setCategory] = useState('');
  const { data, error, loading } = usePoll(() => api(token).events(50, category), 20000, [token, category]);

  const categories = ['', ...Object.keys(CATEGORY_LABELS)];

  return (
    <section className="card">
      <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
        <h2 className="card-title">رویدادهای شبکه</h2>
        <div className="flex flex-wrap gap-1">
          {categories.map((c) => (
            <button
              key={c || 'all'}
              onClick={() => setCategory(c)}
              className={`cursor-pointer rounded-md border px-2 py-1 text-2xs transition-colors ${
                category === c
                  ? 'border-accent bg-accent/10 text-accent'
                  : 'border-line text-muted hover:text-fg'
              }`}
            >
              {c === '' ? 'همه' : CATEGORY_LABELS[c]}
            </button>
          ))}
        </div>
      </div>

      {error && <p className="mb-2 text-2xs text-down">خطا: {error}</p>}
      {loading && !data ? (
        <p className="text-xs text-muted">در حال بارگذاری…</p>
      ) : !data || data.events.length === 0 ? (
        <p className="text-xs text-muted">رویدادی ثبت نشده است.</p>
      ) : (
        <ul className="max-h-72 divide-y divide-line overflow-y-auto">
          {data.events.map((ev) => (
            <li key={`${ev.epoch}-${ev.kind}`} className="flex items-start gap-3 py-2">
              <span
                className="mt-1 inline-block h-2 w-2 shrink-0 rounded-full"
                style={{ background: SEVERITY_COLORS[ev.severity] ?? '#3b82f6' }}
                aria-hidden
              />
              <div className="min-w-0 flex-1">
                <p className="text-xs leading-relaxed">{ev.message}</p>
                <p className="mt-0.5 text-2xs text-muted">
                  {CATEGORY_LABELS[ev.category] ?? ev.category} · {ev.kind} · {ev.actor}
                </p>
              </div>
              <span className="shrink-0 text-2xs text-muted" dir="ltr">
                {timeAgo(ev.epoch)}
              </span>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
