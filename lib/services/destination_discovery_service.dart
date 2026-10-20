import '../models/resrobot_models.dart';
import '../models/travel_preferences.dart';
import 'gateway_client.dart';

class DiscoveryException implements Exception {
  const DiscoveryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DestinationDiscoveryService {
  const DestinationDiscoveryService({required this.gateway});

  final GatewayClient gateway;

  Future<DestinationDiscoveryResult> discover({
    required Location origin,
    required String preferencePrompt,
  }) async {
    final preferences = preferencePrompt.trim();
    if (preferences.isEmpty) {
      throw const DiscoveryException(
        'Describe the destination or experience you are looking for.',
      );
    }
    if (preferences.length > 500) {
      throw const DiscoveryException(
        'Keep your travel description under 500 characters.',
      );
    }

    final Map<String, dynamic> data;
    try {
      data = await gateway.post(
        '/suggestions',
        body: {
          'originId': origin.extId,
          'originName': origin.name,
          'preferences': preferences,
        },
      );
    } on GatewayException catch (error) {
      throw DiscoveryException(error.message);
    }

    final relevant = data['relevant'];
    final journeys = data['journeys'];
    if (relevant is! bool || journeys is! List) {
      throw const DiscoveryException(
        'We couldn’t read the personalized suggestions. Please try again.',
      );
    }
    return DestinationDiscoveryResult(
      isRelevant: relevant,
      message: data['message']?.toString() ?? '',
      journeys: journeys.whereType<Map>().map(_journey).toList(),
    );
  }

  RecommendedJourney _journey(Map<dynamic, dynamic> item) {
    final trip = item['trip'];
    if (trip is! Map) {
      throw const DiscoveryException(
        'We couldn’t read the personalized suggestions. Please try again.',
      );
    }
    return RecommendedJourney(
      idea: DestinationIdea(
        destination: item['destination']?.toString() ?? '',
        reason: item['reason']?.toString() ?? '',
      ),
      stationName: item['stationName']?.toString() ?? '',
      trip: Trip.fromJson(Map<String, dynamic>.from(trip)),
    );
  }
}
