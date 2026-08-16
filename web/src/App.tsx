import { useState } from 'react';
import { api, getToken, setToken, clearToken, ApiError } from './api';
import { HealthGauge } from './components/HealthGauge';
import { StatusStrip } from './components/StatusStrip';
import { EventsFeed } from './components/EventsFeed';
import { LinkCard } from './components/LinkCard';
import { QualityChart } from './components/QualityChart';

// Dashboard pulls its data from the same-origin Router API; every card is a
// separate poller so a slow endpoint can't stall the others.
export function App() {
  const [token, setTokenState] = useState<string>(() => getToken());
  const [ok, setOk] = useState<boolean>(() => getToken() !== '');

  const handleSetup = (t: string) => {
    setToken(t);
    setTokenState(t);
    setOk(t !== '');
  };

  const handleLogout = () => {
    clearToken();
    setTokenState('');
    setOk(false);
  };

  if (!ok) {
    return <Setup token={token} onSubmit={handleSetup} />;
  }

  return (
    <main dir="rtl" className="mx-auto max-w-6xl p-4 sm:p-6">
      <header className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-xl font-black tracking-tight">Xirouter NOC</h1>
          <p className="text-2xs text-muted">مرکز کنترل شبکه — Network Operations Center</p>
        </div>
        <button
          onClick={handleLogout}
          className="cursor-pointer rounded-md border border-line px-3 py-1.5 text-2xs text-muted transition-colors hover:border-down hover:text-down"
        >
          خروج
        </button>
      </header>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
        <div className="md:col-span-1">
          <HealthGauge token={token} />
        </div>
        <div className="md:col-span-1">
          <StatusStrip token={token} />
        </div>
        <div className="md:col-span-2 xl:col-span-1">
          <LinkCard token={token} />
        </div>
        <div className="md:col-span-2">
          <QualityChart token={token} />
        </div>
        <div className="md:col-span-2 xl:col-span-3">
          <EventsFeed token={token} />
        </div>
      </div>
    </main>
  );
}

function Setup({ token, onSubmit }: { token: string; onSubmit: (t: string) => void }) {
  const [value, setValue] = useState(token);
  const [error, setError] = useState('');
  const [checking, setChecking] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setChecking(true);
    setError('');
    try {
      await api(value).health();
      onSubmit(value);
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) {
        setError('توکن اشتباه است — دسترسی رد شد.');
      } else {
        setError(`خطا در ارتباط با روتر (${err instanceof Error ? err.message : 'unknown'})`);
      }
    } finally {
      setChecking(false);
    }
  };

  return (
    <main dir="rtl" className="flex min-h-screen items-center justify-center p-6">
      <form onSubmit={submit} className="card w-full max-w-sm">
        <h1 className="mb-1 text-xl font-black tracking-tight">Xirouter NOC</h1>
        <p className="mb-6 text-2xs text-muted">توکن API روتر را وارد کنید (در /etc/routerapp.conf)</p>
        <label className="mb-2 block text-2xs font-bold text-muted" htmlFor="token">
          توکن API
        </label>
        <input
          id="token"
          dir="ltr"
          className="mb-3 w-full rounded-md border border-line bg-raised px-3 py-2 font-mono text-sm outline-none focus:border-accent"
          value={value}
          onChange={(e) => setValue(e.target.value)}
          placeholder="…"
          autoFocus
        />
        {error && <p className="mb-3 text-xs text-down">{error}</p>}
        <button
          type="submit"
          disabled={checking || !value}
          className="w-full cursor-pointer rounded-md bg-accent px-4 py-2 text-sm font-bold text-bg transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-40"
        >
          {checking ? 'در حال بررسی…' : 'ورود'}
        </button>
      </form>
    </main>
  );
}
