# Gemini destination recommendations

This note explains how the prototype's Gemini integration works behind the
Agile Travellers gateway. It describes the current implementation, what Gemini
does and does not do, known failure modes, and safe development practices.

## What it does

The planner accepts a free-text description such as “a quiet coastal walk with
good seafood,” saved travel interests, or both. Gemini interprets that context
and can return up to three Swedish destination names with a short explanation
for each. A typed description is optional when the user has saved interests.

The app does **not** trust Gemini to produce a public-transport route:

1. The user selects an origin station and provides a destination, travel
   description, saved interests, or a combination.
2. The Flutter app sends the origin and travel description to the gateway
   (`POST /suggestions`). It never contacts Gemini or ResRobot itself.
3. The gateway asks Gemini for a relevance decision plus destination names and
   reasons.
4. The gateway looks each destination up as a station using ResRobot.
5. The gateway asks ResRobot for journeys to the matched station.
6. Only suggestions with a matching ResRobot journey are returned and shown as
   **Recommended for your interests**.

Gemini therefore proposes *where* to go; ResRobot supplies station IDs and
journey details. If Gemini says the prompt is unrelated or too vague, the app
asks the user to describe a place, activity, or travel interest instead.

## Architecture

```text
Flutter app  ──HTTPS──▶  Gateway (Node/Express)  ──▶  ResRobot
 (no API keys)           keys, cache, rate limit  ──▶  Gemini
```

The gateway lives in `gateway/` and is the only component that holds API keys.

Gateway endpoints:

| Endpoint | Purpose |
|---|---|
| `GET` or `POST /routes` | `type=stops&query=…` looks up stops; `type=trips&originId=…&destId=…[&date=YYYY-MM-DD&time=HH:MM]` searches journeys |
| `POST /suggestions` | Body `{ originId, originName, preferences }`; returns validated journeys |
| `GET /health` | Liveness and whether keys are configured (never the values) |

Every response uses one shape:

```json
{ "data": {}, "error": null, "cached": false }
```

On failure `data` is `null` and `error` is `{ "code": "...", "message": "..." }`.
Codes: `invalid_input` (400), `rate_limited` (429), `unavailable` (503), and
`offline`, which the app produces itself when the gateway cannot be reached.
Messages are written for end users and never contain provider names, status
codes, or key details.

Flutter code:

- `lib/services/gateway_client.dart` — the only HTTP client: base URL from
  `--dart-define=GATEWAY_URL`, timeout, envelope parsing, offline detection.
- `lib/services/resrobot_service.dart` — station lookup and journey search
  through `/routes`.
- `lib/services/destination_discovery_service.dart` — recommendations through
  `/suggestions`.
- `lib/models/travel_preferences.dart` — typed recommendation result models.
- `lib/main.dart` — planner logic combining direct and recommended searches.
- `lib/screens/recommendations_screen.dart` — displays the tagged results.

Gateway code (`gateway/src/`): `app.ts` (routes, validation, logging, rate
limit), `gemini.ts` (prompt, model fallback, response validation),
`resrobot.ts`, `suggestions.ts` (Gemini → ResRobot validation), `cache.ts`,
`rateLimit.ts`, `config.ts`.

## Gemini behaviour

The gateway calls Google's Gemini `generateContent` REST endpoint and requests
JSON output. Models come from `GEMINI_MODELS` (default `gemini-3.6-flash`,
then `gemini-flash-latest`). The next model is tried only when the previous one
returns HTTP 404 (model unavailable) or 503 (temporarily overloaded).

The user description is limited to 500 characters. The prompt asks Gemini to
classify relevance and return JSON in this shape:

```json
{
  "relevant": true,
  "message": "",
  "destinations": [
    {
      "destination": "Uppsala",
      "reason": "Historic sites and gardens match your interests."
    }
  ]
}
```

For irrelevant or nonsensical requests, the expected response is
`relevant: false`, a short explanation, and an empty `destinations` list.
Responses are checked before use; the gateway limits results to three and
discards blank or excessively long destination names. If a single station
lookup fails, that idea is skipped; the request only fails when nothing could
be validated.

## Running the gateway locally

Requires Node.js 20.12 or newer.

```powershell
cd gateway
npm install
copy .env.example .env     # then add your real keys
npm run dev                # http://localhost:8787
npm test                   # automated tests (no real keys or network needed)
```

Check it: `curl http://localhost:8787/health`. For a production-style run use
`npm run build` and `npm start`.

### Environment variables

Set in `gateway/.env` (ignored by Git) or the host's environment.

| Variable | Required | Default | Meaning |
|---|---|---|---|
| `RESROBOT_API_KEY` | yes | — | Trafiklab ResRobot key |
| `GEMINI_API_KEY` | for suggestions | — | Google AI Studio key |
| `GEMINI_MODELS` | no | `gemini-3.6-flash,gemini-flash-latest` | Models in fallback order |
| `PORT` | no | `8787` | Listen port |
| `RESROBOT_TIMEOUT_MS` / `GEMINI_TIMEOUT_MS` | no | `8000` / `20000` | Downstream timeouts |
| `CACHE_TTL_SECONDS` | no | `300` | Cache for stops and suggestions |
| `TRIPS_CACHE_TTL_SECONDS` | no | `60` | Cache for journey searches |
| `RATE_LIMIT_MAX` / `RATE_LIMIT_WINDOW_SECONDS` | no | `60` / `60` | Requests per client per window |
| `TRUST_PROXY` | no | `0` | Set `1` behind a reverse proxy |

The cache is in memory: it resets on restart and is not shared between
instances. Only successful responses are cached.

## Pointing the app at the gateway

The gateway URL is a build-time setting; nothing is hard-coded and the app has
no keys.

```powershell
# Android emulator -> gateway running on your computer
flutter run --dart-define=GATEWAY_URL=http://10.0.2.2:8787

# Release APK against a deployed gateway (must be https)
flutter build apk --release --dart-define=GATEWAY_URL=https://your-gateway.example.com
```

Debug builds may use `http://`; release builds must use `https://` because
Android blocks cleartext traffic. A physical phone cannot reach `localhost`;
use your computer's LAN address with a debug build, or deploy the gateway. If
`GATEWAY_URL` is missing, searches show a friendly “not available” message.

## Deploying the gateway (Render)

[render.yaml](../render.yaml) describes the service, so no files need editing.

1. Push the branch containing `render.yaml` and `gateway/` to GitHub.
2. In Render choose **New → Blueprint**, connect the repository and select it.
3. When prompted, enter `RESROBOT_API_KEY` and `GEMINI_API_KEY`. They are
   stored in Render, not in the repository.
4. After the deploy, open `https://<your-service>.onrender.com/health`; it
   should show `"status":"ok"`.
5. Build the APK against that URL:

   ```powershell
   flutter build apk --release --dart-define=GATEWAY_URL=https://<your-service>.onrender.com
   ```

Notes: Render's free tier sleeps after inactivity, so the first search after a
pause can take about a minute (the app then shows a friendly error; retry).
The cache and rate limits reset on each restart. Any host that runs
`npm ci && npm run build` then `npm start` with the same variables also works.

## Key handling

Keys exist only in the gateway environment. Never put real values in
`.env.example`, documentation, source control, screenshots, or chat, and never
pass them to Flutter. Logs record method, path, status, and duration only (no
query strings, bodies, or keys). Before public use, deploy the gateway over
HTTPS, tighten the rate limits, and rotate any key that was ever packaged in an
earlier APK (older builds embedded the keys in the app).

## Limitations and known issues

- Recommendations are generated text, not verified facts. A destination may
  be a poor match, have a similar station name, or fail station lookup.
- Gemini does not provide live weather, opening hours, attractions inventory,
  accessibility details, seat availability, or current disruptions in this
  flow. A request asking for live information should not be treated as a live
  data result.
- The gateway checks that ResRobot can return a journey to a matched station;
  it does not prove the attraction exists, is open, or is near that station.
- Results depend on the selected origin, the user's wording, model behavior,
  model availability, network access, ResRobot data, and the account's current
  Google AI Studio access and quotas.
- Similar wording can produce different results; identical requests inside the
  cache window return the same stored result.
- Relevance classification is a model decision, not a guaranteed moderation or
  semantic-validation system.
- The fallback model may return different destinations or wording. It cannot
  help if both models are unavailable or the key/account has no access.
- The gateway is a single process with in-memory cache and rate limiting; run
  more than one instance and each keeps its own.
- Seat comfort selection is entirely local prototype data and is unrelated to
  Gemini. It neither reads seat inventory nor reserves a seat.

## Common failures

| Situation | User-facing behavior | What to check during development |
|---|---|---|
| No internet, or the gateway is unreachable | “No internet connection. Check your Wi-Fi or mobile data and try again.” | Device connectivity, `GATEWAY_URL`, gateway running, firewall |
| Gateway URL not set | “This feature isn’t available right now.” | Build with `--dart-define=GATEWAY_URL=…` |
| Invalid or missing key/account | Suggestions or journey search “aren’t available right now” | Gateway `.env`, key restrictions, `/health` |
| Model unavailable (404) or overloaded (503) | Gateway tries the fallback model; if both fail, suggests trying later | `GEMINI_MODELS`, Google service status |
| Quota/rate limit (429) | “Temporarily busy / too many requests”, try again shortly | Quota and `RATE_LIMIT_*` settings |
| Slow downstream call | Gateway times out and returns a friendly “unavailable” error | `*_TIMEOUT_MS` |
| Irrelevant prompt | Asks the user for a travel-related description | Try a place, activity, scenery, food, history, or other trip preference |
| No matching stop or route | No recommendation card for that idea | Try another description |

## Testing

```powershell
flutter analyze
flutter test              # app: services mock the gateway
cd gateway; npm test      # gateway: mocks ResRobot and Gemini
```

Tests use mocked HTTP and need no keys or live quota. They cover forwarding,
the unified response format, caching, validation, rate limiting, timeouts,
downstream failures, model fallback, and offline handling. A passing mock test
does not guarantee that a live account or model is currently available.

Official references:

- [Gemini API documentation](https://ai.google.dev/gemini-api/docs)
- [Generate content](https://ai.google.dev/gemini-api/docs/text-generation)
- [Models and supported methods](https://ai.google.dev/api/models)
- [API keys and security guidance](https://ai.google.dev/gemini-api/docs/api-key)
