import { useEffect, useRef, useState } from 'react';

// Poll an API call every `intervalMs`. Returns { data, error, loading }. The
// poll stops when the token changes / component unmounts. Errors surface (e.g.
// 401) rather than silently dying, so the setup screen can react.
export function usePoll<T>(fn: () => Promise<T>, intervalMs: number, deps: unknown[]) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<string>('');
  const [loading, setLoading] = useState(true);
  const fnRef = useRef(fn);
  fnRef.current = fn;

  useEffect(() => {
    let stopped = false;
    let timer: ReturnType<typeof setTimeout>;
    const tick = async () => {
      try {
        const d = await fnRef.current();
        if (!stopped) {
          setData(d);
          setError('');
          setLoading(false);
        }
      } catch (err) {
        if (!stopped) {
          setError(err instanceof Error ? err.message : 'error');
          setLoading(false);
        }
      }
    };
    tick();
    timer = setInterval(tick, intervalMs);
    return () => {
      stopped = true;
      clearInterval(timer);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [intervalMs, ...deps]);

  return { data, error, loading };
}
