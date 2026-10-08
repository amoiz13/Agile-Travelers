# Gemini destination recommendations

This note explains the prototype's Gemini integration for Agile Travellers.
It describes the current implementation, what Gemini does and does not do,
known failure modes, and safe development practices.

## What it does

The planner accepts a free-text description such as “a quiet coastal walk with
good seafood,” saved travel interests, or both. Gemini interprets that context
and can return up to three Swedish destination names with a short explanation
for each. A typed description is optional when the user has saved interests.

The app does **not** trust Gemini to produce a public-transport route:

1. The user selects an origin station and provides a destination, travel
   description, saved interests, or a combination.
2. The Flutter app sends any travel description and saved interests to Gemini.
3. Gemini returns a relevance decision plus destination names and reasons.
4. Agile Travellers looks each destination up as a station using ResRobot.
5. The app asks ResRobot for journeys to the matched station.
6. Only suggestions with a matching ResRobot journey are shown as
   **Recommended for your interests**.

Gemini therefore proposes *where* to go; ResRobot supplies station IDs and
journey details. If Gemini says the prompt is unrelated or too vague, the app
asks the user to describe a place, activity, or travel interest instead.

## Implementation

The integration lives in:

- `lib/services/gemini_recommendation_service.dart` — prompt, HTTP request,
  model fallback, response validation, and user-facing errors.
- `lib/services/destination_discovery_service.dart` — station lookup and
  journey validation using ResRobot.
- `lib/models/travel_preferences.dart` — typed recommendation result models.
- `lib/main.dart` — combines direct-destination search and recommendations
  based on typed descriptions and/or saved interests in the planner.
- `lib/screens/recommendations_screen.dart` — displays the tagged results.

The app uses Google's Gemini `generateContent` REST endpoint and requests JSON
output. The configured model order is `gemini-3.6-flash`, then
`gemini-flash-latest`. The second model is tried only when the first returns
HTTP 404 (model unavailable) or 503 (temporarily overloaded).

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
Responses are checked before use; the app limits results to three and discards
blank or excessively long destination names.

## Configuration and key handling

For local development, add a Google AI Studio key to the ignored `.env` file:

```env
GEMINI_API_KEY=your_key_here
```

Do not add the real value to `.env.example`, documentation, source control,
screenshots, or chat. The application calls Google directly from Flutter, so
the key is packaged into an APK and can be extracted. `.env` and
`--dart-define` keep values out of the repository but do **not** make a
distributed client-side key secret.

This direct-client setup is only appropriate for a controlled prototype.
Before public distribution, put the Gemini call behind a backend or gateway,
apply server-side quotas and abuse controls, and rotate any key that has been
included in an APK shared outside the development team.

## Limitations and known issues

- Recommendations are generated text, not verified facts. A destination may
  be a poor match, have a similar station name, or fail station lookup.
- Gemini does not provide live weather, opening hours, attractions inventory,
  accessibility details, seat availability, or current disruptions in this
  flow. A request asking for live information should not be treated as a live
  data result.
- The app checks that ResRobot can return a journey to a matched station; it
  does not prove the attraction exists, is open, or is near that station.
- Results depend on the selected origin, the user's wording, model behavior,
  model availability, network access, ResRobot data, and the account's current
  Google AI Studio access and quotas.
- Similar wording can produce different results. Relevance classification is
  a model decision, not a guaranteed moderation or semantic-validation system.
- The fallback model may return different destinations or wording. It cannot
  help if both models are unavailable or the key/account has no access.
- Gemini may return malformed, blocked, or empty output. The client reports a
  friendly error rather than displaying unvalidated model content.
- Seat comfort selection is entirely local prototype data and is unrelated to
  Gemini. It neither reads seat inventory nor reserves a seat.

## Common failures

| Situation | User-facing behavior | What to check during development |
|---|---|---|
| No internet | “No internet connection. Check your Wi-Fi or mobile data and try again.” | Device connectivity, DNS, captive portal, or firewall |
| Invalid or unavailable key/account | Personalized suggestions are unavailable; search by destination remains possible | Local `.env`, key restrictions, project/API access; never expose the key in logs |
| Model unavailable (404) | The app tries the fallback model; if that also fails, suggests searching by destination | Model names and current model availability |
| Temporary overload (503) | The app tries the fallback model; if both fail, suggests trying later | Google service status and retry later |
| Quota/rate limit (429) | Suggests trying later or searching by destination | Current project quota and request volume |
| Irrelevant prompt | Asks the user for a travel-related description | Try a place, activity, scenery, food, history, or other trip preference |
| No matching stop or route | No recommendation card for that idea | Try another description; verify the place resolves to a ResRobot stop |

User-facing errors intentionally avoid provider names, API status codes, and
credential details. Detailed HTTP status handling stays inside the services
and tests; do not log API keys or full credential-bearing request URLs.

## Testing

Run the automated suite from the project root:

```powershell
flutter analyze
flutter test
```

The tests use mocked HTTP clients. They cover prompt parsing, irrelevant
prompts, model fallback, provider failures, and offline exceptions without
requiring a real Google key or consuming live quota. A successful mock test
does not guarantee that a live account or model is currently available.

Official references:

- [Gemini API documentation](https://ai.google.dev/gemini-api/docs)
- [Generate content](https://ai.google.dev/gemini-api/docs/text-generation)
- [Models and supported methods](https://ai.google.dev/api/models)
- [API keys and security guidance](https://ai.google.dev/gemini-api/docs/api-key)
