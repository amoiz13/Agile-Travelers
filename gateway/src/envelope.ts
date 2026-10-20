// `offline` is produced by the Flutter client when the gateway cannot be
// reached; the gateway itself only emits the other three codes.
export type ErrorCode =
  | 'offline'
  | 'unavailable'
  | 'invalid_input'
  | 'rate_limited';

export interface Envelope<T> {
  data: T | null;
  error: { code: ErrorCode; message: string } | null;
  cached: boolean;
}

export const STATUS_BY_CODE: Record<ErrorCode, number> = {
  offline: 503,
  unavailable: 503,
  invalid_input: 400,
  rate_limited: 429,
};

// Errors carry only user-safe text; raw downstream details never reach them.
export class GatewayError extends Error {
  constructor(
    readonly code: ErrorCode,
    message: string,
    readonly status: number = STATUS_BY_CODE[code],
  ) {
    super(message);
  }
}

export const ok = <T>(data: T, cached = false): Envelope<T> => ({
  data,
  error: null,
  cached,
});

export const fail = (code: ErrorCode, message: string): Envelope<never> => ({
  data: null,
  error: { code, message },
  cached: false,
});
