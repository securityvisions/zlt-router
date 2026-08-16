import { api } from '../api';
import { usePoll } from '../usePoll';

// The X28 cellular link card (operator/tech/signal/RSRP/flow) — the WAN edge
// the whole network rides on.
export function LinkCard({ token }: { token: string }) {
  const { data, error, loading } = usePoll(() => api(token).link(), 30000, [token]);

  const rows: [string, string][] = [];
  if (data) {
    rows.push(
      ['اپراتور', data.operator || '—'],
      ['تکنولوژی', data.tech || '—'],
      ['سیگنال', data.signal != null ? `${data.signal}/5` : '—'],
      ['RSRP', data.rsrp != null ? `${data.rsrp} dBm` : '—'],
      ['PLMN', data.plmn || '—'],
      ['دانلود', data.flow?.dl != null ? `${data.flow.dl.toFixed(1)} Kbps` : '—'],
      ['آپلود', data.flow?.ul != null ? `${data.flow.ul.toFixed(1)} Kbps` : '—'],
    );
  }

  return (
    <section className="card flex h-full flex-col">
      <h2 className="card-title mb-3">لینک سیم‌کارت (X28)</h2>
      {error && <p className="mb-2 text-2xs text-down">خطا: {error}</p>}
      {loading && !data ? (
        <p className="text-xs text-muted">در حال بارگذاری…</p>
      ) : (
        <ul className="mt-auto space-y-1.5">
          {rows.map(([label, value]) => (
            <li key={label} className="flex items-center justify-between text-xs">
              <span className="text-muted">{label}</span>
              <span className="mono" dir="ltr">
                {value}
              </span>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
