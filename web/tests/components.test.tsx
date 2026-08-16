import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { HealthGauge } from '../src/components/HealthGauge';
import { EventsFeed } from '../src/components/EventsFeed';

describe('HealthGauge', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('renders the score and band from the API', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        status: 200,
        json: async () => ({
          score: 88,
          band: 'Good',
          as_of_unix: 0,
          components: [
            { name: 'link_quality', weight: 30, penalty: 10, detail: 'ALERT|degraded' },
            { name: 'proxy', weight: 20, penalty: 0, detail: 'up' },
          ],
        }),
      }),
    );

    render(<HealthGauge token="t" />);
    expect(await screen.findByText('88')).toBeInTheDocument();
    expect(screen.getByText('Good')).toBeInTheDocument();
    expect(screen.getByText('link_quality')).toBeInTheDocument();
    expect(screen.getByText('proxy')).toBeInTheDocument();
  });
});

describe('EventsFeed', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('lists events newest-first with severity colors', async () => {
    const events = [
      { epoch: 1700000200, category: 'internet', severity: 'critical', kind: 'internet_down', actor: 'passwall-health', message: 'PassWall disabled; direct internet' },
      { epoch: 1700000100, category: 'device', severity: 'info', kind: 'device_joined', actor: '96:04:e1:00:00:00', message: 'New device' },
    ];
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({ ok: true, status: 200, json: async () => ({ events }) }),
    );

    render(<EventsFeed token="t" />);
    expect(await screen.findByText('PassWall disabled; direct internet')).toBeInTheDocument();
    expect(screen.getByText('New device')).toBeInTheDocument();
    expect(screen.getByText('اینترنت')).toBeInTheDocument();
    expect(screen.getByText('دستگاه')).toBeInTheDocument();
  });

  it('shows the empty state', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({ ok: true, status: 200, json: async () => ({ events: [] }) }),
    );
    render(<EventsFeed token="t" />);
    expect(await screen.findByText('رویدادی ثبت نشده است.')).toBeInTheDocument();
  });
});
