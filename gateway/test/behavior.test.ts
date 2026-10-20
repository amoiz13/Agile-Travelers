import { describe, expect, it } from 'vitest';

import {
  SECRET_GEMINI,
  SECRET_RESROBOT,
  geminiBody,
  json,
  setup,
  stopsBody,
  testConfig,
  tripBody,
} from './helpers.js';

describe('caching', () => {
  it('serves identical requests from cache and flags them', async () => {
    const { api, fetchImpl } = setup({
      resrobot: () => json(stopsBody('1', 'Stockholm')),
    });
    const first = await api.get('/routes').query({ type: 'stops', query: 'Stock' });
    const second = await api
      .get('/routes')
      .query({ type: 'stops', query: ' stock ' });

    expect(first.body.cached).toBe(false);
    expect(second.body.cached).toBe(true);
    expect(second.body.data).toEqual(first.body.data);
    expect(fetchImpl).toHaveBeenCalledTimes(1);
  });

  it('does not share cache entries between different requests', async () => {
    const { api, fetchImpl } = setup({
      resrobot: () => json(stopsBody('1', 'Stockholm')),
    });
    await api.get('/routes').query({ type: 'stops', query: 'a' });
    await api.get('/routes').query({ type: 'stops', query: 'b' });
    expect(fetchImpl).toHaveBeenCalledTimes(2);
  });

  it('expires entries after the TTL', async () => {
    let time = 1_000;
    const { api, fetchImpl } = setup(
      { resrobot: () => json(stopsBody('1', 'Stockholm')) },
      testConfig({ cacheTtlMs: 5_000 }),
      { now: () => time },
    );
    const query = { type: 'stops', query: 'Stock' };
    await api.get('/routes').query(query);
    time += 4_000;
    expect((await api.get('/routes').query(query)).body.cached).toBe(true);
    time += 2_000;
    expect((await api.get('/routes').query(query)).body.cached).toBe(false);
    expect(fetchImpl).toHaveBeenCalledTimes(2);
  });

  it('caches suggestions but never caches failures', async () => {
    let geminiCalls = 0;
    const { api } = setup({
      gemini: () => {
        geminiCalls += 1;
        return geminiCalls === 1
          ? json({}, 500)
          : json(geminiBody({ relevant: false, message: '', destinations: [] }));
      },
    });
    const body = { originId: '1', originName: 'Stockholm', preferences: 'Beach' };

    expect((await api.post('/suggestions').send(body)).status).toBe(503);
    const ok1 = await api.post('/suggestions').send(body);
    const ok2 = await api
      .post('/suggestions')
      .send({ ...body, preferences: 'beach' });
    expect(ok1.body.cached).toBe(false);
    expect(ok2.body.cached).toBe(true);
    expect(geminiCalls).toBe(2);
  });
});

describe('downstream error handling', () => {
  const stopsQuery = { type: 'stops', query: 'Stock' };
  const suggestion = { originId: '1', originName: 'Stockholm', preferences: 'lakes' };

  it.each([
    [500, 503, 'unavailable'],
    [503, 503, 'unavailable'],
    [401, 503, 'unavailable'],
    [429, 429, 'rate_limited'],
    [404, 400, 'invalid_input'],
  ])('maps ResRobot %i to %i/%s without leaking details', async (status, expected, code) => {
    const { api } = setup({
      resrobot: () => json({ raw: 'Internal secret detail' }, status),
    });
    const res = await api.get('/routes').query(stopsQuery);
    expect(res.status).toBe(expected);
    expect(res.body.data).toBeNull();
    expect(res.body.error.code).toBe(code);
    const serialized = JSON.stringify(res.body);
    expect(serialized).not.toContain('Internal secret detail');
    expect(serialized).not.toMatch(/resrobot|gemini|api|key|\b[45]\d\d\b/i);
  });

  it('handles network failures without crashing', async () => {
    const { api } = setup({
      resrobot: () => {
        throw new TypeError('fetch failed');
      },
    });
    const res = await api.get('/routes').query(stopsQuery);
    expect(res.status).toBe(503);
    expect(res.body.error.code).toBe('unavailable');

    const health = await api.get('/health');
    expect(health.status).toBe(200);
  });

  it('times out slow downstream calls', async () => {
    const { api } = setup(
      {
        resrobot: (_url, init) =>
          new Promise((_resolve, reject) => {
            init.signal!.addEventListener('abort', () => reject(init.signal!.reason));
          }),
      },
      testConfig({ resrobotTimeoutMs: 50 }),
    );
    const res = await api.get('/routes').query(stopsQuery);
    expect(res.status).toBe(503);
    expect(res.body.error.code).toBe('unavailable');
  });

  it('handles unreadable downstream payloads', async () => {
    const { api } = setup({
      resrobot: () => new Response('<html>nope</html>', { status: 200 }),
    });
    const res = await api.get('/routes').query(stopsQuery);
    expect(res.status).toBe(503);
    expect(res.body.error.code).toBe('unavailable');
  });

  it.each([
    ['gemini 429', () => json({}, 429), 429, 'rate_limited'],
    ['gemini 403', () => json({}, 403), 503, 'unavailable'],
    ['both models 503', () => json({}, 503), 503, 'unavailable'],
    [
      'gemini network failure',
      () => {
        throw new TypeError('fetch failed');
      },
      503,
      'unavailable',
    ],
    [
      'gemini garbage text',
      () => json({ candidates: [{ content: { parts: [{ text: 'nope' }] } }] }),
      503,
      'unavailable',
    ],
    ['gemini empty candidates', () => json({ candidates: [] }), 503, 'unavailable'],
  ])('maps %s safely', async (_name, gemini, status, code) => {
    const { api } = setup({ gemini });
    const res = await api.post('/suggestions').send(suggestion);
    expect(res.status).toBe(status);
    expect(res.body.error.code).toBe(code);
    expect(JSON.stringify(res.body)).not.toMatch(/gemini|resrobot|api|key/i);
  });

  it('propagates a ResRobot failure when no destination could be validated', async () => {
    const { api } = setup({
      gemini: () =>
        json(
          geminiBody({
            relevant: true,
            message: '',
            destinations: [{ destination: 'Uppsala', reason: 'x' }],
          }),
        ),
      resrobot: () => json({}, 500),
    });
    const res = await api.post('/suggestions').send(suggestion);
    expect(res.status).toBe(503);
    expect(res.body.error.code).toBe('unavailable');
  });

  it('keeps valid suggestions when one destination lookup fails', async () => {
    let stopCalls = 0;
    const { api } = setup({
      gemini: () =>
        json(
          geminiBody({
            relevant: true,
            message: '',
            destinations: [
              { destination: 'Uppsala', reason: 'x' },
              { destination: 'Mariefred', reason: 'y' },
            ],
          }),
        ),
      resrobot: (url) => {
        if (!url.pathname.endsWith('/location.name')) {
          return json(tripBody('Mariefred'));
        }
        stopCalls += 1;
        return stopCalls === 1
          ? json({}, 500)
          : json(stopsBody('740000009', 'Mariefred'));
      },
    });
    const res = await api.post('/suggestions').send(suggestion);
    expect(res.status).toBe(200);
    expect(res.body.data.journeys).toHaveLength(1);
    expect(res.body.data.journeys[0].destination).toBe('Mariefred');
  });

  it('reports missing keys as unavailable without calling downstream', async () => {
    const { api, fetchImpl } = setup(
      {},
      testConfig({ resrobotApiKey: '', geminiApiKey: '' }),
    );
    const routes = await api.get('/routes').query(stopsQuery);
    const suggestions = await api.post('/suggestions').send(suggestion);
    expect(routes.status).toBe(503);
    expect(suggestions.status).toBe(503);
    expect(fetchImpl).not.toHaveBeenCalled();
  });

  it('returns the unified shape for unknown routes', async () => {
    const { api } = setup({});
    const res = await api.get('/nope');
    expect(res.status).toBe(404);
    expect(res.body).toEqual({
      data: null,
      error: { code: 'invalid_input', message: expect.any(String) },
      cached: false,
    });
  });
});

describe('health, logging and rate limiting', () => {
  it('reports health without exposing configuration values', async () => {
    const { api } = setup({});
    const res = await api.get('/health');
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('ok');
    expect(res.body.data.services).toEqual({ routes: true, suggestions: true });
    expect(JSON.stringify(res.body)).not.toContain(SECRET_RESROBOT);
  });

  it('logs requests without query strings, bodies or secrets', async () => {
    const { api, logs } = setup({
      resrobot: () => json(stopsBody('1', 'Stockholm')),
      gemini: () => json({}, 500),
    });
    await api.get('/routes').query({ type: 'stops', query: 'private-search' });
    await api
      .post('/suggestions')
      .send({ originId: '1', originName: 'Stockholm', preferences: 'private-text' });

    expect(logs).toHaveLength(2);
    expect(logs[0]).toMatch(/GET \/routes 200 \d+ms/);
    const all = logs.join('\n');
    for (const secret of [
      SECRET_RESROBOT,
      SECRET_GEMINI,
      'private-search',
      'private-text',
    ]) {
      expect(all).not.toContain(secret);
    }
  });

  it('rate limits per client with the unified error shape', async () => {
    const { api } = setup(
      { resrobot: () => json(stopsBody('1', 'Stockholm')) },
      testConfig({ rateLimitMax: 2, rateLimitWindowMs: 60_000 }),
    );
    const query = { type: 'stops', query: 'Stock' };
    expect((await api.get('/routes').query(query)).status).toBe(200);
    expect((await api.get('/routes').query(query)).status).toBe(200);
    const limited = await api.get('/routes').query(query);
    expect(limited.status).toBe(429);
    expect(limited.body.error.code).toBe('rate_limited');
    expect(limited.headers['retry-after']).toBeDefined();
    expect((await api.get('/health')).status).toBe(200);
  });

  it('resets the rate limit after the window', async () => {
    let time = 0;
    const { api } = setup(
      { resrobot: () => json(tripBody('x')) },
      testConfig({ rateLimitMax: 1, rateLimitWindowMs: 1_000 }),
      { now: () => time },
    );
    const query = { type: 'stops', query: 'a' };
    await api.get('/routes').query(query);
    expect((await api.get('/routes').query(query)).status).toBe(429);
    time += 1_500;
    expect((await api.get('/routes').query(query)).status).toBe(200);
  });
});
