import 'dart:convert';
import 'dart:io';

import 'package:agile_travelers/models/resrobot_models.dart';
import 'package:agile_travelers/services/destination_discovery_service.dart';
import 'package:agile_travelers/services/gateway_client.dart';
import 'package:agile_travelers/services/network_unavailable_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'gateway_client_test.dart' show envelope;

const origin = Location(
  name: 'Stockholm',
  extId: '740000001',
  time: '',
  date: '',
  lat: 59.3,
  lon: 18.0,
);

DestinationDiscoveryService serviceFor(MockClientHandler handler) =>
    DestinationDiscoveryService(
      gateway: GatewayClient(
        baseUrl: 'https://gateway.test',
        client: MockClient(handler),
      ),
    );

void main() {
  group('DestinationDiscoveryService via gateway', () {
    test('posts the request and maps verified journeys', () async {
      final service = serviceFor((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/suggestions');
        expect(jsonDecode(request.body), {
          'originId': '740000001',
          'originName': 'Stockholm',
          'preferences': 'historic places',
        });
        return envelope(
          data: {
            'relevant': true,
            'message': 'Here you go.',
            'journeys': [
              {
                'destination': 'Uppsala',
                'reason': 'Historic sites and gardens.',
                'stationName': 'Uppsala Centralstation',
                'trip': {
                  'duration': 'PT40M',
                  'transferCount': 0,
                  'Origin': {'name': 'Stockholm'},
                  'Destination': {'name': 'Uppsala Centralstation'},
                  'LegList': {'Leg': []},
                },
              },
            ],
          },
        );
      });

      final result = await service.discover(
        origin: origin,
        preferencePrompt: '  historic places  ',
      );

      expect(result.isRelevant, isTrue);
      expect(result.message, 'Here you go.');
      expect(result.journeys, hasLength(1));
      expect(result.journeys.single.stationName, 'Uppsala Centralstation');
      expect(result.journeys.single.idea.reason, contains('Historic'));
      expect(result.journeys.single.trip.destination.name, 'Uppsala Centralstation');
    });

    test('returns the rejection message for unrelated prompts', () async {
      final service = serviceFor(
        (_) async => envelope(
          data: {
            'relevant': false,
            'message': "I couldn't make a trip recommendation from that prompt.",
            'journeys': [],
          },
        ),
      );
      final result = await service.discover(
        origin: origin,
        preferencePrompt: 'asdf',
      );
      expect(result.isRelevant, isFalse);
      expect(result.journeys, isEmpty);
      expect(result.message, contains("couldn't make a trip recommendation"));
    });

    test('returns an empty result when no journeys were verified', () async {
      final service = serviceFor(
        (_) async => envelope(
          data: {'relevant': true, 'message': 'No matches.', 'journeys': []},
        ),
      );
      final result = await service.discover(
        origin: origin,
        preferencePrompt: 'beach',
      );
      expect(result.isRelevant, isTrue);
      expect(result.journeys, isEmpty);
    });

    test('validates the prompt without calling the gateway', () async {
      final service = serviceFor(
        (_) async => throw Exception('Should not be called'),
      );
      await expectLater(
        service.discover(origin: origin, preferencePrompt: '  '),
        throwsA(isA<DiscoveryException>()),
      );
      await expectLater(
        service.discover(origin: origin, preferencePrompt: 'a' * 501),
        throwsA(isA<DiscoveryException>()),
      );
    });

    test('surfaces gateway 5xx errors as friendly messages', () async {
      final service = serviceFor(
        (_) async => envelope(
          error: {
            'code': 'unavailable',
            'message': 'Personalized suggestions are temporarily busy.',
          },
          status: 503,
        ),
      );
      await expectLater(
        service.discover(origin: origin, preferencePrompt: 'lakes'),
        throwsA(
          isA<DiscoveryException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('temporarily busy'),
              isNot(contains('Gemini')),
              isNot(contains('503')),
            ),
          ),
        ),
      );
    });

    test('throws the offline exception when the gateway is unreachable', () async {
      final service = serviceFor((_) async => throw const SocketException('x'));
      await expectLater(
        service.discover(origin: origin, preferencePrompt: 'lakes'),
        throwsA(isA<NetworkUnavailableException>()),
      );
    });

    test('throws the offline exception on timeout', () async {
      final service = DestinationDiscoveryService(
        gateway: GatewayClient(
          baseUrl: 'https://gateway.test',
          timeout: const Duration(milliseconds: 20),
          client: MockClient(
            (_) => Future.delayed(
              const Duration(seconds: 1),
              () => envelope(data: {}),
            ),
          ),
        ),
      );
      await expectLater(
        service.discover(origin: origin, preferencePrompt: 'lakes'),
        throwsA(isA<NetworkUnavailableException>()),
      );
    });

    test('rejects malformed gateway data with a friendly message', () async {
      final service = serviceFor(
        (_) async => envelope(data: {'relevant': 'yes'}),
      );
      await expectLater(
        service.discover(origin: origin, preferencePrompt: 'lakes'),
        throwsA(isA<DiscoveryException>()),
      );
    });
  });
}
