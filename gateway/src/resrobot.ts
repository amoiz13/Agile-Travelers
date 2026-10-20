import type { Config } from './config.js';
import { GatewayError } from './envelope.js';
import { type FetchLike, requestWithTimeout } from './http.js';

const BASE_URL = 'https://api.resrobot.se/v2.1';

export type Json = Record<string, unknown>;

export interface TripQuery {
  originId: string;
  destId: string;
  date?: string;
  time?: string;
}

export interface ResRobotClient {
  stops(query: string): Promise<Json[]>;
  trips(query: TripQuery): Promise<Json[]>;
}

const asArray = (value: unknown): unknown[] =>
  Array.isArray(value) ? value : value == null ? [] : [value];

const asObjects = (value: unknown): Json[] =>
  asArray(value).filter(
    (item): item is Json => typeof item === 'object' && item !== null,
  );

// ResRobot expects Swedish local time when no departure time is supplied.
function stockholmNow(): { date: string; time: string } {
  const parts = new Intl.DateTimeFormat('sv-SE', {
    timeZone: 'Europe/Stockholm',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).formatToParts(new Date());
  const get = (type: string) =>
    parts.find((part) => part.type === type)?.value ?? '00';
  return {
    date: `${get('year')}-${get('month')}-${get('day')}`,
    time: `${get('hour')}:${get('minute')}`,
  };
}

export function createResRobotClient(
  config: Config,
  fetchImpl: FetchLike,
): ResRobotClient {
  async function get(path: string, params: Record<string, string>): Promise<Json> {
    if (!config.resrobotApiKey) {
      throw new GatewayError(
        'unavailable',
        'Journey search is not available right now. Please try again later.',
      );
    }
    const url = new URL(`${BASE_URL}${path}`);
    for (const [key, value] of Object.entries(params)) {
      url.searchParams.set(key, value);
    }
    url.searchParams.set('accessId', config.resrobotApiKey);
    url.searchParams.set('format', 'json');

    let response: Response;
    try {
      response = await requestWithTimeout(
        fetchImpl,
        url.toString(),
        {},
        config.resrobotTimeoutMs,
      );
    } catch {
      throw new GatewayError(
        'unavailable',
        'We couldn’t load journey information right now. Please try again.',
      );
    }
    if (!response.ok) throw mapStatus(response.status);
    try {
      const body: unknown = await response.json();
      if (typeof body === 'object' && body !== null && !Array.isArray(body)) {
        return body as Json;
      }
    } catch {
      // Falls through to the shared unreadable-response error.
    }
    throw new GatewayError(
      'unavailable',
      'We couldn’t read the journey information. Please try again.',
    );
  }

  return {
    async stops(query) {
      const body = await get('/location.name', { input: query });
      const raw =
        body.stopLocationOrCoordLocation ?? body.StopLocation ?? body.locations;
      return asObjects(raw)
        .map((item) => item.StopLocation)
        .filter(
          (stop): stop is Json => typeof stop === 'object' && stop !== null,
        );
    },

    async trips({ originId, destId, date, time }) {
      const now = date && time ? null : stockholmNow();
      const body = await get('/trip', {
        originId,
        destId,
        date: date ?? now!.date,
        time: time ?? now!.time,
      });
      const tripList = body.TripList as Json | undefined;
      return asObjects(body.Trip ?? tripList?.Trip);
    },
  };
}

function mapStatus(status: number): GatewayError {
  if (status === 400 || status === 404) {
    return new GatewayError(
      'invalid_input',
      'We couldn’t find a journey for those stations. Check your selections and try again.',
    );
  }
  if (status === 429) {
    return new GatewayError(
      'rate_limited',
      'Journey search is busy right now. Please try again shortly.',
    );
  }
  return new GatewayError(
    'unavailable',
    status >= 500
      ? 'Journey search is temporarily unavailable. Please try again shortly.'
      : 'We couldn’t load journey information. Please try again.',
  );
}
