import 'dart:convert';

import 'package:agile_travelers/models/resrobot_models.dart';
import 'package:agile_travelers/services/destination_discovery_service.dart';
import 'package:agile_travelers/services/gemini_recommendation_service.dart';
import 'package:agile_travelers/services/resrobot_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('resolves Gemini ideas and returns only ResRobot journeys', () async {
    final gemini = GeminiRecommendationService(
      apiKey: 'test-key',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({
                        'relevant': true,
                        'message': '',
                        'destinations': [
                          {
                            'destination': 'Uppsala',
                            'reason': 'Historic sites and gardens.',
                          },
                        ],
                      }),
                    },
                  ],
                },
              },
            ],
          }),
          200,
        ),
      ),
    );
    final resRobot = ResRobotService(
      apiKey: 'resrobot-test-key',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/location.name')) {
          return http.Response(
            jsonEncode({
              'stopLocationOrCoordLocation': [
                {
                  'StopLocation': {
                    'extId': '740000002',
                    'name': 'Uppsala Centralstation',
                  },
                },
              ],
            }),
            200,
          );
        }
        expect(request.url.path, endsWith('/trip'));
        expect(request.url.queryParameters['originId'], '740000001');
        expect(request.url.queryParameters['destId'], '740000002');
        return http.Response(
          jsonEncode({
            'TripList': {
              'Trip': [
                {
                  'duration': 'PT40M',
                  'transferCount': 0,
                  'Origin': {'name': 'Stockholm'},
                  'Destination': {'name': 'Uppsala Centralstation'},
                  'LegList': {
                    'Leg': [
                      {
                        'type': 'JNY',
                        'Origin': {'name': 'Stockholm'},
                        'Destination': {'name': 'Uppsala Centralstation'},
                      },
                    ],
                  },
                },
              ],
            },
          }),
          200,
        );
      }),
    );
    const origin = Location(
      name: 'Stockholm',
      extId: '740000001',
      time: '',
      date: '',
      lat: 59.3,
      lon: 18.0,
    );
    final service = DestinationDiscoveryService(
      gemini: gemini,
      resRobot: resRobot,
    );

    final recommendations = await service.discover(
      origin: origin,
      preferencePrompt: 'I enjoy historic places and quiet gardens.',
    );

    expect(recommendations.journeys, hasLength(1));
    expect(
      recommendations.journeys.single.stationName,
      'Uppsala Centralstation',
    );
    expect(recommendations.journeys.single.idea.reason, contains('Historic'));
    expect(
      recommendations.journeys.single.trip.destination.name,
      'Uppsala Centralstation',
    );
    expect(recommendations.isRelevant, isTrue);
  });
}
