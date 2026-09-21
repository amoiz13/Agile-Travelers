import 'dart:convert';
import 'dart:io';

import 'package:agile_travelers/services/resrobot_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const apiKey = 'test_api_key';

  group('ResRobotService Network Tests', () {
    test('stopLookup returns locations on successful API call (200 OK)', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/v2.1/location.name');
        expect(request.url.queryParameters['input'], 'Stockholm');
        expect(request.url.queryParameters['accessId'], apiKey);

        final jsonResponse = {
          "stopLocationOrCoordLocation": [
            {
              "StopLocation": {
                "extId": "740000001",
                "name": "Stockholm Central",
                "lat": 59.330,
                "lon": 18.058,
                "time": "10:00",
                "date": "2026-09-06"
              }
            }
          ]
        };
        return http.Response(jsonEncode(jsonResponse), 200);
      });

      final service = ResRobotService(apiKey: apiKey, client: mockClient);
      final results = await service.stopLookup('Stockholm');

      expect(results, isNotEmpty);
      expect(results.length, 1);
      expect(results.first.extId, '740000001');
      expect(results.first.name, 'Stockholm Central');
    });

    test('stopLookup returns empty list for empty query without making API call', () async {
      // MockClient will throw if a request is actually made, since we don't return a response here
      final mockClient = MockClient((request) async => throw Exception('Should not be called'));
      final service = ResRobotService(apiKey: apiKey, client: mockClient);
      
      final results = await service.stopLookup('   ');
      expect(results, isEmpty);
    });

    test('searchTrips returns trips on successful API call (200 OK)', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/v2.1/trip');
        expect(request.url.queryParameters['originId'], '740000001');
        expect(request.url.queryParameters['destId'], '740000002');
        
        final jsonResponse = {
          "TripList": {
            "Trip": [
              {
                "duration": "PT1H",
                "transferCount": 0,
                "Origin": {"name": "Stockholm Central"},
                "Destination": {"name": "Uppsala Central"},
                "LegList": {
                  "Leg": [
                    {
                      "id": "leg_1",
                      "type": "JNY",
                      "duration": "PT1H",
                      "Origin": {"name": "Stockholm Central"},
                      "Destination": {"name": "Uppsala Central"}
                    }
                  ]
                }
              }
            ]
          }
        };
        return http.Response(jsonEncode(jsonResponse), 200);
      });

      final service = ResRobotService(apiKey: apiKey, client: mockClient);
      final response = await service.searchTrips(originId: '740000001', destId: '740000002');

      expect(response.trips, isNotEmpty);
      expect(response.trips.length, 1);
      expect(response.trips.first.duration, 'PT1H');
      expect(response.trips.first.legs.length, 1);
      expect(response.trips.first.legs.first.type, 'JNY');
    });

    test('throws ResRobotException on HTTP Error (e.g., 500 Server Error)', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = ResRobotService(apiKey: apiKey, client: mockClient);

      expect(
        () => service.stopLookup('Stockholm'),
        throwsA(isA<ResRobotException>().having((e) => e.message, 'message', contains('failed (500)'))),
      );
    });

    test('throws ResRobotException on Network Error (e.g., SocketException)', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('No Internet');
      });

      final service = ResRobotService(apiKey: apiKey, client: mockClient);

      expect(
        () => service.searchTrips(originId: '1', destId: '2'),
        throwsA(isA<ResRobotException>().having((e) => e.message, 'message', contains('Could not reach ResRobot'))),
      );
    });

    test('throws ResRobotException on Malformed JSON', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not a JSON string', 200); // 200 OK but invalid JSON
      });

      final service = ResRobotService(apiKey: apiKey, client: mockClient);

      expect(
        () => service.stopLookup('Stockholm'),
        throwsA(isA<ResRobotException>()),
      );
    });
  });
}

