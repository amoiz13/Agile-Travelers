import 'dart:io';

import 'package:agile_travelers/services/gateway_client.dart';
import 'package:agile_travelers/services/network_unavailable_exception.dart';
import 'package:agile_travelers/services/resrobot_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'gateway_client_test.dart' show envelope;

ResRobotService serviceFor(MockClientHandler handler) => ResRobotService(
  gateway: GatewayClient(
    baseUrl: 'https://gateway.test',
    client: MockClient(handler),
  ),
);

void main() {
  group('ResRobotService via gateway', () {
    test('stopLookup returns locations from the gateway', () async {
      final service = serviceFor((request) async {
        expect(request.url.path, '/routes');
        expect(request.url.queryParameters['type'], 'stops');
        expect(request.url.queryParameters['query'], 'Stockholm');
        return envelope(
          data: {
            'stops': [
              {
                'extId': '740000001',
                'name': 'Stockholm Central',
                'lat': 59.330,
                'lon': 18.058,
              },
            ],
          },
        );
      });

      final results = await service.stopLookup('Stockholm');
      expect(results, hasLength(1));
      expect(results.first.extId, '740000001');
      expect(results.first.name, 'Stockholm Central');
    });

    test('stopLookup returns an empty list when nothing matches', () async {
      final service = serviceFor((_) async => envelope(data: {'stops': []}));
      expect(await service.stopLookup('zzz'), isEmpty);
    });

    test('stopLookup skips the call for an empty query', () async {
      final service = serviceFor(
        (_) async => throw Exception('Should not be called'),
      );
      expect(await service.stopLookup('   '), isEmpty);
    });

    test('searchTrips returns trips from the gateway', () async {
      final service = serviceFor((request) async {
        expect(request.url.path, '/routes');
        expect(request.url.queryParameters['type'], 'trips');
        expect(request.url.queryParameters['originId'], '740000001');
        expect(request.url.queryParameters['destId'], '740000002');
        expect(request.url.queryParameters['date'], '2026-10-20');
        expect(request.url.queryParameters['time'], '09:05');
        return envelope(
          data: {
            'trips': [
              {
                'duration': 'PT1H',
                'transferCount': 0,
                'Origin': {'name': 'Stockholm Central'},
                'Destination': {'name': 'Uppsala Central'},
                'LegList': {
                  'Leg': [
                    {
                      'id': 'leg_1',
                      'type': 'JNY',
                      'duration': 'PT1H',
                      'Origin': {'name': 'Stockholm Central'},
                      'Destination': {'name': 'Uppsala Central'},
                    },
                  ],
                },
              },
            ],
          },
        );
      });

      final response = await service.searchTrips(
        originId: '740000001',
        destId: '740000002',
        date: DateTime(2026, 10, 20, 9, 5),
      );
      expect(response.trips, hasLength(1));
      expect(response.trips.first.duration, 'PT1H');
      expect(response.trips.first.legs.first.type, 'JNY');
    });

    test('searchTrips returns no trips when none are found', () async {
      final service = serviceFor((_) async => envelope(data: {'trips': []}));
      final response = await service.searchTrips(originId: '1', destId: '2');
      expect(response.trips, isEmpty);
    });

    test('shows a friendly message on a gateway 5xx error', () async {
      final service = serviceFor(
        (_) async => envelope(
          error: {
            'code': 'unavailable',
            'message':
                'Journey search is temporarily unavailable. Please try again shortly.',
          },
          status: 503,
        ),
      );
      await expectLater(
        service.stopLookup('Stockholm'),
        throwsA(
          isA<ResRobotException>().having(
            (e) => e.message,
            'message',
            contains('temporarily unavailable'),
          ),
        ),
      );
    });

    test('maps invalid_input and rate_limited to friendly messages', () async {
      for (final entry in {
        'invalid_input': 'We couldn’t find a journey for those stations.',
        'rate_limited': 'Journey search is busy right now.',
      }.entries) {
        final service = serviceFor(
          (_) async => envelope(
            error: {'code': entry.key, 'message': entry.value},
            status: 400,
          ),
        );
        await expectLater(
          service.searchTrips(originId: '1', destId: '2'),
          throwsA(
            isA<ResRobotException>().having(
              (e) => e.message,
              'message',
              entry.value,
            ),
          ),
        );
      }
    });

    test('throws the offline exception when the gateway is unreachable', () async {
      final service = serviceFor((_) async => throw const SocketException('x'));
      await expectLater(
        service.searchTrips(originId: '1', destId: '2'),
        throwsA(
          isA<NetworkUnavailableException>().having(
            (e) => e.toString(),
            'message',
            contains('No internet connection'),
          ),
        ),
      );
    });

    test('throws a friendly exception on malformed data', () async {
      final service = serviceFor(
        (_) async => envelope(data: {'stops': 'not a list'}),
      );
      await expectLater(
        service.stopLookup('Stockholm'),
        throwsA(isA<ResRobotException>()),
      );
    });
  });
}
