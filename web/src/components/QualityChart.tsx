import { api } from '../api';
import { usePoll } from '../usePoll';

// Hourly link-quality chart: passive throughput bars + latency line. The data
// comes from /quality (the telemetry-log rollup), rendered with plain SVG so
// the dist stays dependency-free.
export function QualityChart({ token }: { token: string }) {
  const { data, error, loading } = usePoll(() => api(token).quality(24), 60000, [token]);

  const W = 600;
  const H = 180;
  const pad = { top: 12, right: 12, bottom: 24, left: 8 };

  if (error) return <section className="card"><h2 className="card-title mb-3">کیفیت لینک</h2><p className="text-xs text-down">خطا: {error}</p></section>;
  if (loading && !data) return <section className="card"><h2 className="card-title mb-3">کیفیت لینک</h2><p className="text-xs text-muted">در حال بارگذاری…</p></section>;

  const points = data?.points ?? [];
  if (points.length === 0) {
    return (
      <section className="card">
        <h2 className="card-title mb-3">کیفیت لینک</h2>
        <p className="text-xs text-muted">داده‌ای موجود نیست.</p>
      </section>
    );
  }

  const max = Math.max(2, ...points.map((p) => p.passive_mbps));
  const innerW = W - pad.left - pad.right;
  const innerH = H - pad.top - pad.bottom;
  const step = innerW / points.length;

  const bars = points.map((p, i) => {
    const h = (p.passive_mbps / max) * innerH;
    return (
      <rect
        key={`b-${i}`}
        x={pad.left + i * step + step * 0.15}
        y={pad.top + innerH - h}
        width={step * 0.7}
        height={h}
        rx={2}
        fill="#22c55e"
        opacity={0.65}
      />
    );
  });

  // latency polyline (seconds *100 -> height scale; draw on top)
  const latMax = Math.max(0.1, ...points.map((p) => p.latency_s || 0));
  const latPts = points
    .map((p, i) => {
      const x = pad.left + i * step + step / 2;
      const y = pad.top + innerH - (p.latency_s / latMax) * innerH;
      return `${x},${y}`;
    })
    .join(' ');

  return (
    <section className="card">
      <h2 className="card-title mb-3">کیفیت لینک — ۲۴ ساعت اخیر</h2>
      <svg viewBox={`0 0 ${W} ${H}`} className="w-full" role="img" aria-label="کیفیت لینک ساعتی">
        {bars}
        <polyline points={latPts} fill="none" stroke="#f59e0b" strokeWidth="2" />
        <text x={pad.left} y={H - 6} className="fill-muted text-[10px]">
          {points[0]?.ts ?? ''}
        </text>
        <text x={W - pad.right} y={H - 6} textAnchor="end" className="fill-muted text-[10px]">
          {points[points.length - 1]?.ts ?? ''}
        </text>
      </svg>
      <div className="mt-2 flex items-center gap-4 text-2xs text-muted">
        <span className="flex items-center gap-1"><span className="inline-block h-2 w-2 rounded-sm bg-[#22c55e] opacity-65" /> throughput (Mbps)</span>
        <span className="flex items-center gap-1"><span className="inline-block h-0.5 w-3 bg-[#f59e0b]" /> latency</span>
      </div>
    </section>
  );
}
