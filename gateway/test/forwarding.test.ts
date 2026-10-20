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

const resrobotOk = (url: URL) =>
  url.pathname.endsWith('/location.name')
    ? json(stopsBody('740000002', 'Uppsala Centralstation'))
    : json(tripBody('Uppsala Centralstation'));

describe('/routes forwarding and unified format', () => {
  it('forwards stop lookups with the server-side key and wraps the data', async () => {
    const { api, fetchImpl } = setup({ resrobot: resrobotOk });
    const res = await api.get('/routes').query({ type: 'stops', query: 'Upps' });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      data: {
        stops: [{ extId: '740000002', name: 'Uppsala Centralstation' }],
      },
      error: null,
      cached: false,
    });
    const url = new URL(String(fetchImpl.mock.calls[0]![0]));
    expect(url.searchParams.get('input')).toBe('Upps');
    expect(url.searchParams.get('accessId')).toBe(SECRET_RESROBOT);
  });

  it('forwards journey searches via GET and POST', async () => {
    const { api } = setup({ resrobot: resrobotOk });
    const query = {
      type: 'trips',
      originId: '740000001',
      destId: '740000002',
      date: '2026-10-20',
      time: '10:30',
    };
    const viaGet = await api.get('/routes').query(query);
    const viaPost = await api.post('/routes').send(query);

    for (const res of [viaGet, viaPost]) {
      expect(res.status).toBe(200);
      expect(res.body.error).toBeNull();
      expect(res.body.data.trips).toHaveLength(1);
      expect(res.body.data.trips[0].Destination.name).toBe(
        'Uppsala Centralstation',
      );
    }
  });

  it('returns an empty list when nothing matches (empty state)', async () => {
    const { api } = setup({ resrobot: () => json({}) });
    const res = await api.get('/routes').query({ type: 'stops', query: 'zzz' });
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({ stops: [] });
  });

  it.each([
    ['unknown type', { type: 'nope' }],
    ['missing query', { type: 'stops' }],
    ['non-numeric ids', { type: 'trips', originId: 'abc', destId: '2' }],
    [
      'bad date',
      { type: 'trips', originId: '1', destId: '2', date: 'x', time: '10:00' },
    ],
    [
      'date without time',
      { type: 'trips', originId: '1', destId: '2', date: '2026-10-20' },
    ],
    ['overlong query', { type: 'stops', query: 'a'.repeat(101) }],
  ])('rejects invalid input: %s', async (_name, query) => {
    const { api, fetchImpl } = setup({ resrobot: resrobotOk });
    const res = await api.get('/routes').query(query);
    expect(res.status).toBe(400);
    expect(res.body.data).toBeNull();
    expect(res.body.error.code).toBe('invalid_input');
    expect(fetchImpl).not.toHaveBeenCalled();
  });
});

describe('/suggestions', () => {
  const geminiOk = () =>
    json(
      geminiBody({
        relevant: true,
        message: '',
        destinations: [
          { destination: 'Uppsala', reason: 'Historic sites and gardens.' },
        ],
      }),
    );
  const body = {
    originId: '740000001',
    originName: 'Stockholm',
    preferences: 'historic places',
  };

  it('has Gemini propose, then validates each destination with ResRobot', async () => {
    const { api, fetchImpl } = setup({
      gemini: geminiOk,
      resrobot: resrobotOk,
    });
    const res = await api.post('/suggestions').send(body);

    expect(res.status).toBe(200);
    expect(res.body.error).toBeNull();
    expect(res.body.data.relevant).toBe(true);
    expect(res.body.data.journeys).toHaveLength(1);
    expect(res.body.data.journeys[0]).toMatchObject({
      destination: 'Uppsala',
      reason: 'Historic sites and gardens.',
      stationName: 'Uppsala Centralstation',
    });
    expect(res.body.data.journeys[0].trip.Destination.name).toBe(
      'Uppsala Centralstation',
    );
    const geminiCall = fetchImpl.mock.calls.find(([url]) =>
      String(url).includes('generativelanguage'),
    )!;
    expect(
      (geminiCall[1]!.headers as Record<string, string>)['x-goog-api-key'],
    ).toBe(SECRET_GEMINI);
    expect(String(geminiCall[0])).not.toContain(SECRET_GEMINI);
  });

  it('drops ideas that have no real stop or journey (empty state)', async () => {
    const { api } = setup({
      gemini: geminiOk,
      resrobot: (url) =>
        url.pathname.endsWith('/location.name')
          ? json(stopsBody('740000002', 'Uppsala'))
          : json({ TripList: {} }),
    });
    const res = await api.post('/suggestions').send(body);
    expect(res.status).toBe(200);
    expect(res.body.data.relevant).toBe(true);
    expect(res.body.data.journeys).toEqual([]);
    expect(res.body.data.message).toContain('no matching journeys');
    expect(res.body.data.message).not.toMatch(/resrobot|gemini/i);
  });

  it('skips a destination equal to the origin', async () => {
    const { api } = setup({
      gemini: geminiOk,
      resrobot: (url) =>
        url.pathname.endsWith('/location.name')
          ? json(stopsBody('740000001', 'Stockholm'))
          : json(tripBody('Stockholm')),
    });
    const res = await api.post('/suggestions').send(body);
    expect(res.body.data.journeys).toEqual([]);
  });

  it('reports unrelated prompts without calling ResRobot', async () => {
    const { api, fetchImpl } = setup({
      gemini: () =>
        json(geminiBody({ relevant: false, message: '', destinations: [] })),
    });
    const res = await api.post('/suggestions').send(body);
    expect(res.status).toBe(200);
    expect(res.body.data.relevant).toBe(false);
    expect(res.body.data.message).toContain("couldn't make a trip recommendation");
    expect(fetchImpl).toHaveBeenCalledTimes(1);
  });

  it('limits suggestions to three destinations', async () => {
    const { api } = setup({
      gemini: () =>
        json(
          geminiBody({
            relevant: true,
            message: '',
            destinations: ['A', 'B', 'C', 'D', 'E'].map((destination) => ({
              destination,
              reason: 'x',
            })),
          }),
        ),
      resrobot: resrobotOk,
    });
    const res = await api.post('/suggestions').send(body);
    expect(res.body.data.journeys).toHaveLength(3);
  });

  it('falls back to the next model on 404 and on 503', async () => {
    for (const status of [404, 503]) {
      const models: string[] = [];
      const { api } = setup({
        gemini: (url) => {
          models.push(url.pathname);
          return models.length === 1
            ? json({ error: { message: 'raw' } }, status)
            : geminiOk();
        },
        resrobot: resrobotOk,
      });
      const res = await api.post('/suggestions').send(body);
      expect(res.status).toBe(200);
      expect(res.body.data.journeys).toHaveLength(1);
      expect(models).toEqual([
        '/v1beta/models/gemini-3.6-flash:generateContent',
        '/v1beta/models/gemini-flash-latest:generateContent',
      ]);
    }
  });

  it('uses model names from configuration', async () => {
    const models: string[] = [];
    const { api } = setup(
      {
        gemini: (url) => {
          models.push(url.pathname);
          return geminiOk();
        },
        resrobot: resrobotOk,
      },
      testConfig({ geminiModels: ['custom-model'] }),
    );
    await api.post('/suggestions').send(body);
    expect(models).toEqual(['/v1beta/models/custom-model:generateContent']);
  });

  it.each([
    ['missing preferences', { ...body, preferences: '  ' }],
    ['overlong preferences', { ...body, preferences: 'a'.repeat(501) }],
    ['bad origin id', { ...body, originId: 'x' }],
    ['missing origin name', { ...body, originName: undefined }],
  ])('rejects invalid input: %s', async (_name, payload) => {
    const { api, fetchImpl } = setup({ gemini: geminiOk, resrobot: resrobotOk });
    const res = await api.post('/suggestions').send(payload);
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('invalid_input');
    expect(fetchImpl).not.toHaveBeenCalled();
  });

  it('rejects malformed JSON bodies', async () => {
    const { api } = setup({});
    const res = await api
      .post('/suggestions')
      .set('Content-Type', 'application/json')
      .send('{not json');
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('invalid_input');
  });
});
