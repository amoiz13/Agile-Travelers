export interface Config {
  port: number;
  resrobotApiKey: string;
  geminiApiKey: string;
  geminiModels: string[];
  resrobotTimeoutMs: number;
  geminiTimeoutMs: number;
  cacheTtlMs: number;
  tripsCacheTtlMs: number;
  rateLimitMax: number;
  rateLimitWindowMs: number;
  trustProxy: boolean;
}

const DEFAULT_MODELS = ['gemini-3.6-flash', 'gemini-flash-latest'];

function positiveInt(value: string | undefined, fallback: number): number {
  const parsed = Number.parseInt(value ?? '', 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

export function loadConfig(
  env: Record<string, string | undefined> = process.env,
): Config {
  const models = (env.GEMINI_MODELS ?? '')
    .split(',')
    .map((model) => model.trim())
    .filter(Boolean);
  return {
    port: positiveInt(env.PORT, 8787),
    resrobotApiKey: (env.RESROBOT_API_KEY ?? '').trim(),
    geminiApiKey: (env.GEMINI_API_KEY ?? '').trim(),
    geminiModels: models.length > 0 ? models : DEFAULT_MODELS,
    resrobotTimeoutMs: positiveInt(env.RESROBOT_TIMEOUT_MS, 8000),
    geminiTimeoutMs: positiveInt(env.GEMINI_TIMEOUT_MS, 20000),
    cacheTtlMs: positiveInt(env.CACHE_TTL_SECONDS, 300) * 1000,
    tripsCacheTtlMs: positiveInt(env.TRIPS_CACHE_TTL_SECONDS, 60) * 1000,
    rateLimitMax: positiveInt(env.RATE_LIMIT_MAX, 60),
    rateLimitWindowMs: positiveInt(env.RATE_LIMIT_WINDOW_SECONDS, 60) * 1000,
    trustProxy: env.TRUST_PROXY === '1',
  };
}
