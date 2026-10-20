import express, {
  type NextFunction,
  type Request,
  type Response,
} from 'express';
import { randomUUID } from 'node:crypto';

import { TtlCache } from './cache.js';
import type { Config } from './config.js';
import { GatewayError, fail, ok } from './envelope.js';
import { createGeminiClient } from './gemini.js';
import type { FetchLike } from './http.js';
import { rateLimit } from './rateLimit.js';
import { createResRobotClient } from './resrobot.js';
import { suggestJourneys } from './suggestions.js';

export interface AppDeps {
  config: Config;
  fetchImpl?: FetchLike;
  now?: () => number;
  log?: (line: string) => void;
}

const ID = /^\d{1,20}$/;
const DATE = /^\d{4}-\d{2}-\d{2}$/;
const TIME = /^\d{2}:\d{2}(:\d{2})?$/;

const invalid = (message: string) =>
  new GatewayError('invalid_input', message);

function text(value: unknown, field: string, max: number): string {
  if (typeof value !== 'string' || value.trim() === '') {
    throw invalid(`Please provide ${field}.`);
  }
  const trimmed = value.trim();
  if (trimmed.length > max) {
    throw invalid(`${field[0]!.toUpperCase()}${field.slice(1)} is too long.`);
  }
  return trimmed;
}

function matching(value: unknown, pattern: RegExp, field: string): string {
  if (typeof value !== 'string' || !pattern.test(value)) {
    throw invalid(`Please provide a valid ${field}.`);
  }
  return value;
}

function params(req: Request): Record<string, unknown> {
  const source = req.method === 'POST' ? req.body : req.query;
  return typeof source === 'object' && source !== null ? source : {};
}

export function createApp({
  config,
  fetchImpl = fetch,
  now = Date.now,
  log = (line) => console.log(line),
}: AppDeps) {
  const app = express();
  const cache = new TtlCache(500, now);
  const resrobot = createResRobotClient(config, fetchImpl);
  const gemini = createGeminiClient(config, fetchImpl);

  app.disable('x-powered-by');
  if (config.trustProxy) app.set('trust proxy', 1);

  // Logs method, path, status and timing only: no query strings, bodies or keys.
  app.use((req, res, next) => {
    const start = now();
    const id = randomUUID().slice(0, 8);
    res.on('finish', () => {
      log(
        `${id} ${req.method} ${req.path} ${res.statusCode} ${now() - start}ms`,
      );
    });
    next();
  });

  app.use(express.json({ limit: '10kb' }));

  app.get('/health', (_req, res) => {
    res.json(
      ok({
        status: 'ok',
        services: {
          routes: config.resrobotApiKey !== '',
          suggestions:
            config.resrobotApiKey !== '' && config.geminiApiKey !== '',
        },
      }),
    );
  });

  app.use(['/routes', '/suggestions'], rateLimit(config.rateLimitMax, config.rateLimitWindowMs, now));

  async function cached<T>(
    key: string,
    ttlMs: number,
    compute: () => Promise<T>,
  ) {
    const hit = cache.get<T>(key);
    if (hit !== undefined) return ok(hit, true);
    const value = await compute();
    cache.set(key, value, ttlMs);
    return ok(value, false);
  }

  const routes = async (req: Request, res: Response) => {
    const input = params(req);
    if (input.type === 'stops') {
      const query = text(input.query, 'a station name', 100);
      const key = `stops:${query.toLowerCase()}`;
      res.json(
        await cached(key, config.cacheTtlMs, async () => ({
          stops: await resrobot.stops(query),
        })),
      );
      return;
    }
    if (input.type === 'trips') {
      const originId = matching(input.originId, ID, 'origin');
      const destId = matching(input.destId, ID, 'destination');
      const date =
        input.date === undefined ? undefined : matching(input.date, DATE, 'date');
      const time =
        input.time === undefined ? undefined : matching(input.time, TIME, 'time');
      if ((date === undefined) !== (time === undefined)) {
        throw invalid('Please provide both a date and a time.');
      }
      const key = `trips:${originId}:${destId}:${date ?? ''}:${time ?? ''}`;
      res.json(
        await cached(key, config.tripsCacheTtlMs, async () => ({
          trips: await resrobot.trips({ originId, destId, date, time }),
        })),
      );
      return;
    }
    throw invalid('Please choose what to look up: stops or trips.');
  };
  app.get('/routes', routes);
  app.post('/routes', routes);

  app.post('/suggestions', async (req, res) => {
    const input = params(req);
    const originId = matching(input.originId, ID, 'origin');
    const originName = text(input.originName, 'an origin name', 100);
    const preferences = text(input.preferences, 'your travel preferences', 500);
    const key = `suggestions:${originId}:${preferences.toLowerCase()}`;
    res.json(
      await cached(key, config.cacheTtlMs, () =>
        suggestJourneys(gemini, resrobot, { originId, originName, preferences }),
      ),
    );
  });

  app.use((_req, res) => {
    res.status(404).json(fail('invalid_input', 'That request isn’t supported.'));
  });

  app.use((error: unknown, _req: Request, res: Response, _next: NextFunction) => {
    if (error instanceof GatewayError) {
      res.status(error.status).json(fail(error.code, error.message));
      return;
    }
    const status = (error as { status?: number } | null)?.status;
    if (status === 400 || status === 413) {
      res
        .status(400)
        .json(fail('invalid_input', 'The request couldn’t be understood.'));
      return;
    }
    log(`unhandled error ${(error as Error | null)?.name ?? 'unknown'}`);
    res
      .status(500)
      .json(
        fail('unavailable', 'Something went wrong. Please try again shortly.'),
      );
  });

  return app;
}
