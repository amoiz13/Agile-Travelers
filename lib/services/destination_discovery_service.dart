import '../models/resrobot_models.dart';
import '../models/travel_preferences.dart';
import 'gemini_recommendation_service.dart';
import 'resrobot_service.dart';

class DestinationDiscoveryService {
  const DestinationDiscoveryService({
    required this.gemini,
    required this.resRobot,
  });

  final GeminiRecommendationService gemini;
  final ResRobotService resRobot;

  Future<DestinationDiscoveryResult> discover({
    required Location origin,
    required String preferencePrompt,
  }) async {
    final recommendations = await gemini.recommendDestinations(
      origin: origin.name,
      preferencePrompt: preferencePrompt,
    );
    if (!recommendations.isRelevant) {
      return DestinationDiscoveryResult(
        isRelevant: false,
        message: recommendations.message,
      );
    }
    final journeys = <RecommendedJourney>[];
    for (final idea in recommendations.destinations) {
      final stations = await resRobot.stopLookup(idea.destination);
      if (stations.isEmpty) continue;
      final station = stations.first;
      if (station.extId.isEmpty || station.extId == origin.extId) continue;
      final response = await resRobot.searchTrips(
        originId: origin.extId,
        destId: station.extId,
      );
      if (response.trips.isEmpty) continue;
      journeys.add(
        RecommendedJourney(
          idea: idea,
          stationName: station.name,
          trip: response.trips.first,
        ),
      );
    }
    if (journeys.isEmpty) {
      return const DestinationDiscoveryResult(
        isRelevant: true,
        message:
            'The prompt matched a travel interest, but no matching '
            'ResRobot journeys were found. Try a different description.',
      );
    }
    return DestinationDiscoveryResult(
      isRelevant: true,
      message: recommendations.message,
      journeys: journeys,
    );
  }
}
