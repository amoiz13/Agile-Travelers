import '../models/resrobot_models.dart';
import 'gateway_client.dart';

class ResRobotException implements Exception {
  const ResRobotException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ResRobotService {
  ResRobotService({required this.gateway});

  final GatewayClient gateway;

  Future<TripResponse> searchTrips({
    required String originId,
    required String destId,
    DateTime? date,
  }) async {
    final departure = date ?? DateTime.now();
    final data = await _get({
      'type': 'trips',
      'originId': originId,
      'destId': destId,
      'date': _date(departure),
      'time': _time(departure),
    });
    return TripResponse.fromJson({'Trip': _list(data['trips'])});
  }

  Future<List<Location>> stopLookup(String query) async {
    if (query.trim().isEmpty) return const [];
    final data = await _get({'type': 'stops', 'query': query.trim()});
    return _list(data['stops'])
        .whereType<Map>()
        .map((stop) => Location.fromJson(Map<String, dynamic>.from(stop)))
        .toList();
  }

  Future<Map<String, dynamic>> _get(Map<String, String> query) async {
    try {
      return await gateway.get('/routes', query: query);
    } on GatewayException catch (error) {
      throw ResRobotException(error.message);
    }
  }

  List<dynamic> _list(Object? value) {
    if (value is List) return value;
    throw const ResRobotException(
      'We couldn’t read the journey information. Please try again.',
    );
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
