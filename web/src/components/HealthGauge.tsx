import { api } from '../api';
import { usePoll } from '../usePoll';

const BAND_COLORS: Record<string, string> = {
  Excellent: '#22c55e',
  Good: '#84cc16',
  Degraded: '#f59e0b',
  Poor: '#ef4444',
};

// Radial gauge of the derived Network Health Score (ADR-0005) with the band
// color and the per-component breakdown beneath it.
export function HealthGauge({ token }: { token: string }) {
  const { data, error, loading } = usePoll(() => api(token).health(), 15000, [token]);

  const score = data?.score ?? 0;
  const band = data?.band ?? 'Poor';
  const color = BAND_COLORS[band] ?? '#ef4444';
  const r = 54;
  const c = 2 * Math.PI * r;

  return (
    <section className="card flex h-full flex-col">
      <h2 className="card-title mb-3">امتیاز سلامت شبکه</h2>
      <div className="relative mx-auto my-2 h-36 w-36">
        <svg viewBox="0 0 128 128" className="h-full w-full -rotate-90">
          <circle cx="64" cy="64" r={r} fill="none" stroke="#26262e" strokeWidth="10" />
          <circle
            cx="64"
            cy="64"
            r={r}
            fill="none"
            stroke={color}
            strokeWidth="10"
            strokeLinecap="round"
            strokeDasharray={c}
            strokeDashoffset={c * (1 - Math.max(0, Math.min(1, score / 100)))}
            className="transition-[stroke-dashoffset] duration-500"
          />
        </svg>
        <div className="absolute inset-0 flex flex-col items-center justify-center">
          <span className="mono text-3xl font-bold">{loading ? '…' : score}</span>
          <span className="text-2xs text-muted">{band}</span>
        </div>
      </div>

      {error && <p className="mb-2 text-2xs text-down">خطا: {error}</p>}

      <ul className="mt-auto space-y-1.5">
        {(data?.components ?? []).map((comp) => (
          <li key={comp.name} className="flex items-center justify-between text-xs">
            <span className="text-muted">{comp.name}</span>
            <span className="mono" style={{ color: comp.penalty > 0 ? '#f59e0b' : '#22c55e' }}>
              {comp.penalty}
            </span>
          </li>
        ))}
      </ul>
    </section>
  );
}
