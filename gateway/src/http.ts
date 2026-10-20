export type FetchLike = typeof fetch;

export class DownstreamError extends Error {
  constructor(readonly kind: 'network' | 'timeout') {
    super(kind);
  }
}

// Wraps fetch with a hard timeout. Errors are reduced to a kind so that URLs
// (which may contain credentials) can never leak into logs or responses.
export async function requestWithTimeout(
  fetchImpl: FetchLike,
  url: string,
  init: RequestInit,
  timeoutMs: number,
): Promise<Response> {
  try {
    return await fetchImpl(url, {
      ...init,
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch (error) {
    const name = (error as { name?: string } | null)?.name;
    throw new DownstreamError(
      name === 'TimeoutError' || name === 'AbortError' ? 'timeout' : 'network',
    );
  }
}
