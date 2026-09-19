import 'package:flutter_test/flutter_test.dart';

import 'package:agile_travellers/models/resrobot_models.dart';
import 'package:agile_travellers/utils/co2_calculator.dart';

void main() {
  const location = Location(
    name: 'Test',
    extId: '1',
    time: '10:00',
    date: '2026-09-06',
    lat: 0,
    lon: 0,
  );

  test('calculates train emissions from GIS distance', () {
    const leg = Leg(
      id: 'train',
      name: 'Train',
      type: 'JNY',
      category: 'JST',
      duration: 'PT1H',
      origin: location,
      destination: location,
      products: [],
      notes: [],
      gisRoute: GisRoute(distanceMeters: 10000),
    );
    const trip = Trip(
      duration: 'PT1H',
      transferCount: 0,
      origin: location,
      destination: location,
      legs: [leg],
    );

    expect(calculateTripCO2(trip), '0.1 kg CO2');
    expect(calculateLegCO2(leg), '0.1 kg CO2');
  });

  test('parses nested GIS route and product category', () {
    final leg = Leg.fromJson({
      'type': 'JNY',
      'Product': {'catOut': 'JST'},
      'Origin': {'name': 'A'},
      'Destination': {'name': 'B'},
      'GISRoute': {'dist': 5000},
    });

    expect(leg.gisRoute?.distanceMeters, 5000);
    expect(calculateLegCO2(leg), '0.1 kg CO2');
  });

  test('calculates local bus emissions using ResRobot BLT category', () {
    final leg = Leg.fromJson({
      'type': 'JNY',
      'category': 'BLT',
      'Origin': {'name': 'A'},
      'Destination': {'name': 'B'},
      'GisRoute': {'dist': 10000},
      'dist': 10000,
    });

    expect(calculateLegCO2(leg), '0.7 kg CO2');
  });
}
