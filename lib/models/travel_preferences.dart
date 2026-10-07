import 'resrobot_models.dart';

class TravelPreferences {
  const TravelPreferences({this.interests = const []});

  static const availableInterests = [
    'History & heritage',
    'Nature & scenery',
    'Food & cafés',
    'Art & culture',
    'Family activities',
    'Shopping',
  ];

  final List<String> interests;
}

class DestinationIdea {
  const DestinationIdea({required this.destination, required this.reason});

  final String destination;
  final String reason;
}

class DestinationRecommendationResult {
  const DestinationRecommendationResult({
    required this.isRelevant,
    required this.message,
    this.destinations = const [],
  });

  final bool isRelevant;
  final String message;
  final List<DestinationIdea> destinations;
}

class DestinationDiscoveryResult {
  const DestinationDiscoveryResult({
    required this.isRelevant,
    required this.message,
    this.journeys = const [],
  });

  final bool isRelevant;
  final String message;
  final List<RecommendedJourney> journeys;
}

class RecommendedJourney {
  const RecommendedJourney({
    required this.idea,
    required this.stationName,
    required this.trip,
  });

  final DestinationIdea idea;
  final String stationName;
  final Trip trip;
}
