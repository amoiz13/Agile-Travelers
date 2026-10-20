import type { NextFunction, Request, Response } from 'express';

import { fail } from './envelope.js';

export function rateLimit(
  max: number,
  windowMs: number,
  now: () => number = Date.now,
) {
  const hits = new Map<string, { count: number; resetAt: number }>();

  return (req: Request, res: Response, next: NextFunction) => {
    const time = now();
    for (const [key, entry] of hits) {
      if (entry.resetAt <= time) hits.delete(key);
    }
    const key = req.ip ?? 'unknown';
    const entry = hits.get(key) ?? { count: 0, resetAt: time + windowMs };
    entry.count += 1;
    hits.set(key, entry);
    if (entry.count > max) {
      res
        .status(429)
        .set('Retry-After', String(Math.ceil((entry.resetAt - time) / 1000)))
        .json(
          fail(
            'rate_limited',
            'Too many requests. Please wait a moment and try again.',
          ),
        );
      return;
    }
    next();
  };
}
