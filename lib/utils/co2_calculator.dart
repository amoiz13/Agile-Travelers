import 'dart:math';
import '../models/resrobot_models.dart';

String calculateTripCO2(Trip trip) {
  final grams = calculateTripCO2Grams(trip);
  return '${(grams / 1000).toStringAsFixed(1)} kg CO2';
}

double calculateTripDistanceKm(Trip trip) => trip.legs.fold<double>(
      0,
      (total, leg) => total + calculateLegDistanceKm(leg),
    );

double calculateTripCO2Grams(Trip trip) => trip.legs.fold<double>(
      0,
      (total, leg) =>
          total + (calculateLegDistanceKm(leg) * _emissionFactor(leg)),
    );

String calculateLegCO2(Leg leg) {
  final kilograms = (calculateLegDistanceKm(leg) * _emissionFactor(leg)) / 1000;
  return '${kilograms.toStringAsFixed(1)} kg CO2';
}

String formatDistance(double kilometers) {
  if (kilometers < 1) {
    return '${(kilometers * 1000).round()} m';
  }
  return '${kilometers.toStringAsFixed(kilometers < 10 ? 1 : 0)} km';
}

double calculateLegDistanceKm(Leg leg) {
  final apiDistance = leg.gisRoute?.distanceMeters ?? 0;
  if (apiDistance > 0) {
    return apiDistance / 1000;
  }

  final lat1 = leg.origin.lat;
  final lon1 = leg.origin.lon;
  final lat2 = leg.destination.lat;
  final lon2 = leg.destination.lon;

  if (!_validCoordinate(lat1, lon1) || !_validCoordinate(lat2, lon2)) {
    return 0;
  }

  return _calculateHaversine(lat1, lon1, lat2, lon2) * 1.2;
}

bool _validCoordinate(double lat, double lon) =>
    lat != 0 && lon != 0 && lat.abs() <= 90 && lon.abs() <= 180;

double _calculateHaversine(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371; // Earth's radius in kilometers
  final dLat = _degToRad(lat2 - lat1);
  final dLon = _degToRad(lon2 - lon1);
  
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_degToRad(lat1)) * cos(_degToRad(lat2)) *
      sin(dLon / 2) * sin(dLon / 2);
      
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c; // Distance in km
}

double _degToRad(double deg) => deg * (pi / 180.0);

double _emissionFactor(Leg leg) {
  final type = leg.type.toUpperCase();
  final categories = <String>{
    if (leg.category.isNotEmpty) leg.category.toUpperCase(),
    ...leg.products
        .map((product) => product.category.toUpperCase())
        .where((category) => category.isNotEmpty),
  };

  if (type == 'WALK' || categories.contains('WALK')) return 0;
  if (categories.any(const {'JST', 'JRE', 'JLT'}.contains)) return 14;
  if (categories.any((c) => c == 'BXB' || c == 'BLT' || c.startsWith('B'))) return 68;
  
  return 0;
}