import request from 'supertest';
import { vi } from 'vitest';

import { createApp } from '../src/app.js';
import { type Config, loadConfig } from '../src/config.js';

export const SECRET_RESROBOT = 'resrobot-secret-value';
export const SECRET_GEMINI = 'gemini-secret-value';

export const testConfig = (overrides: Partial<Config> = {}): Config => ({
  ...loadConfig({
    RESROBOT_API_KEY: SECRET_RESROBOT,
    GEMINI_API_KEY: SECRET_GEMINI,
  }),
  ...overrides,
});

export const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

export const stopsBody = (extId: string, name: string) => ({
  stopLocationOrCoordLocation: [{ StopLocation: { extId, name } }],
});

export const tripBody = (name: string) => ({
  TripList: {
    Trip: [
      {
        duration: 'PT40M',
        Origin: { name: 'Stockholm' },
        Destination: { name },
        LegList: { Leg: [] },
      },
    ],
  },
});

export const geminiBody = (result: unknown) => ({
  candidates: [{ content: { parts: [{ text: JSON.stringify(result) }] } }],
});

export type Route = (url: URL, init: RequestInit) => Response | Promise<Response>;

// Routes mocked downstream calls by host so tests never touch the network.
export function setup(
  routes: { resrobot?: Route; gemini?: Route },
  config: Config = testConfig(),
  extra: { now?: () => number } = {},
) {
  const logs: string[] = [];
  const fetchImpl = vi.fn(async (input: URL | RequestInfo, init?: RequestInit) => {
    const url = new URL(String(input));
    const route = url.hostname.includes('resrobot')
      ? routes.resrobot
      : routes.gemini;
    if (!route) throw new Error('unexpected downstream call');
    return route(url, init ?? {});
  });
  const app = createApp({
    config,
    fetchImpl: fetchImpl as unknown as typeof fetch,
    log: (line) => logs.push(line),
    ...extra,
  });
  return { api: request(app), fetchImpl, logs };
}
