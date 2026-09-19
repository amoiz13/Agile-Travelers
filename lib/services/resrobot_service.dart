import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/resrobot_models.dart';

class ResRobotException implements Exception {
  const ResRobotException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ResRobotService {
  ResRobotService({required this.apiKey, required this.client});

  static const _baseUrl = 'https://api.resrobot.se/v2.1';
  final String apiKey;
  final http.Client client;

  Future<TripResponse> searchTrips({
    required String originId,
    required String destId,
    DateTime? date,
  }) async {
    final departure = date ?? DateTime.now();
    final uri = Uri.parse('$_baseUrl/trip').replace(queryParameters: {
      'accessId': apiKey,
      'originId': originId,
      'destId': destId,
      'date': _date(departure),
      'time': _time(departure),
      'format': 'json',
    });
    return TripResponse.fromJson(_decode(await _get(uri)));
  }

  Future<List<Location>> stopLookup(String query) async {
    if (query.trim().isEmpty) return const [];
    final uri = Uri.parse('$_baseUrl/location.name').replace(queryParameters: {
      'accessId': apiKey,
      'input': query.trim(),
      'format': 'json',
    });
    final json = _decode(await _get(uri));
    final raw = json['stopLocationOrCoordLocation'] ??
        json['StopLocation'] ??
        json['locations'] ??
        const [];
    final values = raw is List ? raw : [raw];
    return values
        .whereType<Map>()
        .where((value) => value['StopLocation'] is Map)
        .map((value) => Location.fromJson(
              Map<String, dynamic>.from(value['StopLocation'] as Map),
            ))
        .toList();
  }

  Future<String> _get(Uri uri) async {
    try {
      final response = await client.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ResRobotException(
          'ResRobot request failed (${response.statusCode}).',
        );
      }
      return response.body;
    } on ResRobotException {
      rethrow;
    } on Exception catch (error) {
      throw ResRobotException('Could not reach ResRobot: $error');
    }
  }

  Map<String, dynamic> _decode(String body) {
    final value = jsonDecode(body);
    if (value is! Map) {
      throw const ResRobotException('ResRobot returned an unexpected response.');
    }
    return Map<String, dynamic>.from(value);
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';
}
