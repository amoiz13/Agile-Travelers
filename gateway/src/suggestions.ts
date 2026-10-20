import type { GeminiClient } from './gemini.js';
import type { Json, ResRobotClient } from './resrobot.js';

export interface SuggestionsInput {
  originId: string;
  originName: string;
  preferences: string;
}

export interface SuggestedJourney {
  destination: string;
  reason: string;
  stationName: string;
  trip: Json;
}

export interface SuggestionsResult {
  relevant: boolean;
  message: string;
  journeys: SuggestedJourney[];
}

// Gemini proposes destinations; only ones ResRobot confirms as a real stop with
// a real journey from the origin are returned.
export async function suggestJourneys(
  gemini: GeminiClient,
  resrobot: ResRobotClient,
  { originId, originName, preferences }: SuggestionsInput,
): Promise<SuggestionsResult> {
  const recommendation = await gemini.recommend(originName, preferences);
  if (!recommendation.relevant) {
    return { relevant: false, message: recommendation.message, journeys: [] };
  }

  const journeys: SuggestedJourney[] = [];
  let failure: unknown;
  for (const idea of recommendation.destinations) {
    try {
      const [station] = await resrobot.stops(idea.destination);
      const extId = station?.extId;
      if (typeof extId !== 'string' || extId === '' || extId === originId) {
        continue;
      }
      const [trip] = await resrobot.trips({ originId, destId: extId });
      if (!trip) continue;
      journeys.push({
        destination: idea.destination,
        reason: idea.reason,
        stationName: String(station?.name ?? idea.destination),
        trip,
      });
    } catch (error) {
      failure = error;
    }
  }
  // A failed lookup only skips that idea; fail outright if nothing validated.
  if (journeys.length === 0 && failure) throw failure;

  if (journeys.length === 0) {
    return {
      relevant: true,
      message:
        'The prompt matched a travel interest, but no matching journeys were found. Try a different description.',
      journeys: [],
    };
  }
  return { relevant: true, message: recommendation.message, journeys };
}
