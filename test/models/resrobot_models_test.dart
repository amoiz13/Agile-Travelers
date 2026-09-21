import 'package:agile_travelers/models/resrobot_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResRobot Models Data Layer Tests', () {
    test('Location.fromJson correctly parses location data', () {
      final json = {
        'name': 'Stockholm Central',
        'extId': '740000001',
        'time': '10:00',
        'date': '2026-09-06',
        'lat': 59.330,
        'lon': 18.058,
      };

      final location = Location.fromJson(json);

      expect(location.name, 'Stockholm Central');
      expect(location.extId, '740000001');
      expect(location.time, '10:00');
      expect(location.date, '2026-09-06');
      expect(location.lat, 59.330);
      expect(location.lon, 18.058);
    });

    test('Location.fromJson falls back to "id" if "extId" is missing', () {
      final json = {
        'name': 'Uppsala Central',
        'id': '740000002',
        'lat': '59.858', // String to test double parsing
        'lon': '17.645',
      };

      final location = Location.fromJson(json);

      expect(location.extId, '740000002');
      expect(location.lat, 59.858);
      expect(location.lon, 17.645);
      expect(location.time, '');
      expect(location.date, '');
    });

    test('Leg.fromJson parses a walking leg (minimal data)', () {
      final json = {
        'id': '1',
        'type': 'WALK',
        'duration': 'PT10M',
        'Origin': {
          'name': 'A',
          'lat': 59.3,
          'lon': 18.0
        },
        'Destination': {
          'name': 'B',
          'lat': 59.4,
          'lon': 18.1
        },
      };

      final leg = Leg.fromJson(json);

      expect(leg.type, 'WALK');
      expect(leg.duration, 'PT10M');
      expect(leg.origin.name, 'A');
      expect(leg.destination.name, 'B');
      expect(leg.category, '');
      expect(leg.products, isEmpty);
      expect(leg.gisRoute, isNull);
    });

    test('Leg.fromJson parses a transit leg (with Product and GISRoute)', () {
      final json = {
        'type': 'JNY',
        'name': 'Train 123',
        'Product': {
          'catOut': 'JST',
          'operator': 'SJ',
          'line': '45'
        },
        'Origin': {'name': 'Stockholm'},
        'Destination': {'name': 'Uppsala'},
        'dist': 70000,
        'Notes': {
          'Note': [
            {'value': 'Bicycle allowed'}
          ]
        }
      };

      final leg = Leg.fromJson(json);

      expect(leg.type, 'JNY');
      expect(leg.name, 'Train 123');
      expect(leg.category, 'JST');
      expect(leg.products.length, 1);
      expect(leg.products.first.operator, 'SJ');
      expect(leg.products.first.line, '45');
      expect(leg.products.first.category, 'JST');
      expect(leg.notes.length, 1);
      expect(leg.notes.first.text, 'Bicycle allowed');
      expect(leg.gisRoute?.distanceMeters, 70000);
    });

    test('TripResponse.fromJson parses nested trips correctly', () {
      final json = {
        'TripList': {
          'Trip': [
            {
              'duration': 'PT1H30M',
              'transferCount': 1,
              'Origin': {'name': 'Stockholm'},
              'Destination': {'name': 'Uppsala'},
              'LegList': {
                'Leg': [
                  {
                    'type': 'JNY',
                    'Origin': {'name': 'Stockholm'},
                    'Destination': {'name': 'Uppsala'}
                  }
                ]
              }
            }
          ]
        }
      };

      final response = TripResponse.fromJson(json);

      expect(response.trips.length, 1);
      final trip = response.trips.first;
      expect(trip.duration, 'PT1H30M');
      expect(trip.transferCount, 1);
      expect(trip.origin.name, 'Stockholm');
      expect(trip.destination.name, 'Uppsala');
      expect(trip.legs.length, 1);
      expect(trip.legs.first.type, 'JNY');
    });
  });
}

