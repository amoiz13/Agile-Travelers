class TripResponse {
  const TripResponse({required this.trips});

  final List<Trip> trips;

  factory TripResponse.fromJson(Map<String, dynamic> json) {
    final tripList = json['TripList'];
    final raw = json['Trip'] ??
        (tripList is Map ? tripList['Trip'] : null) ??
        json['tripList'] ??
        json['trips'] ??
        const [];
    final values = raw is List ? raw : [raw];
    return TripResponse(
      trips: values
          .whereType<Map>()
          .map((value) => Trip.fromJson(Map<String, dynamic>.from(value)))
          .toList(),
    );
  }
}

class Trip {
  const Trip({
    required this.duration,
    required this.transferCount,
    required this.origin,
    required this.destination,
    required this.legs,
  });

  final String duration;
  final int transferCount;
  final Location origin;
  final Location destination;
  final List<Leg> legs;

  factory Trip.fromJson(Map<String, dynamic> json) {
    final legList = json['LegList'];
    final raw = legList is Map ? legList['Leg'] : json['legs'];
    final values = raw is List ? raw : [raw];
    return Trip(
      duration: _string(json['duration']),
      transferCount: _int(json['transferCount'] ?? json['transfers']),
      origin: Location.fromJson(_map(json['Origin'] ?? json['origin'])),
      destination: Location.fromJson(_map(json['Destination'] ?? json['destination'])),
      legs: values
          .whereType<Map>()
          .map((value) => Leg.fromJson(Map<String, dynamic>.from(value)))
          .toList(),
    );
  }
}

class Leg {
  const Leg({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    required this.duration,
    required this.origin,
    required this.destination,
    required this.products,
    required this.notes,
    this.gisRoute,
  });

  final String id;
  final String name;
  final String type;
  final String category;
  final String duration;
  final Location origin;
  final Location destination;
  final List<Product> products;
  final List<Note> notes;
  final GisRoute? gisRoute;

  factory Leg.fromJson(Map<String, dynamic> json) {
    final product = json['Product'] ?? json['product'];
    final productValue = product is Map && product['Product'] != null
        ? product['Product']
        : product;
    final products = productValue is List ? productValue : [productValue];
    final notesContainer = json['Notes'];
    final note = notesContainer is Map ? notesContainer['Note'] : json['notes'];
    final notes = note is List ? note : [note];
    final journey = json['Journey'];
    return Leg(
      id: _string(json['id']),
      name: _string(json['name'] ?? (journey is Map ? journey['name'] : null)),
      type: _string(json['type']),
      category: _string(
        json['category'] ??
            (products.whereType<Map>().isNotEmpty
                ? products.whereType<Map>().first['catOut']
                : null),
      ),
      duration: _string(json['duration']),
      origin: Location.fromJson(_map(json['Origin'] ?? json['origin'])),
      destination: Location.fromJson(_map(json['Destination'] ?? json['destination'])),
      products: products
          .whereType<Map>()
          .map((value) => Product.fromJson(Map<String, dynamic>.from(value)))
          .toList(),
      notes: notes
          .whereType<Map>()
          .map((value) => Note.fromJson(Map<String, dynamic>.from(value)))
          .toList(),
      gisRoute: _gisRoute(json),
    );
  }
}

class Location {
  const Location({
    required this.name,
    required this.extId,
    required this.time,
    required this.date,
    required this.lat,
    required this.lon,
  });

  final String name;
  final String extId;
  final String time;
  final String date;
  final double lat;
  final double lon;

  factory Location.fromJson(Map<String, dynamic> json) => Location(
        name: _string(json['name']),
        extId: _string(json['extId'] ?? json['id']),
        time: _string(json['time']),
        date: _string(json['date']),
        lat: _double(json['lat']),
        lon: _double(json['lon']),
      );
}

class Product {
  const Product({
    required this.operator,
    required this.line,
    required this.category,
  });

  final String operator;
  final String line;
  final String category;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        operator: _string(json['operator'] ?? json['Operator']),
        line: _string(json['line'] ?? json['num']),
        category: _string(json['category'] ?? json['catOut']),
      );
}

class Note {
  const Note({required this.text});

  final String text;

  factory Note.fromJson(Map<String, dynamic> json) =>
      Note(text: _string(json['value'] ?? json['text'] ?? json['name']));
}

class GisRoute {
  const GisRoute({required this.distanceMeters});

  final int distanceMeters;

  factory GisRoute.fromJson(Map<String, dynamic> json) =>
      GisRoute(distanceMeters: _int(json['dist']));
}

GisRoute? _gisRoute(Map<String, dynamic> json) {
  final distance = _intOrNull(json['dist']) ?? _findDistance(json);
  return distance == null ? null : GisRoute(distanceMeters: distance);
}

int? _findDistance(dynamic value) {
  if (value is Map) {
    for (final entry in value.entries) {
      final key = entry.key.toString().toLowerCase().replaceAll('_', '');
      if (key == 'dist' || key == 'distance' || key == 'distancemeters') {
        final parsed = _intOrNull(entry.value);
        if (parsed != null) return parsed;
      }
      final nested = _findDistance(entry.value);
      if (nested != null) return nested;
    }
  } else if (value is List) {
    for (final item in value) {
      final nested = _findDistance(item);
      if (nested != null) return nested;
    }
  }
  return null;
}

int? _intOrNull(dynamic value) {
  final text = value?.toString();
  if (text == null) return null;
  return int.tryParse(text) ?? double.tryParse(text)?.round();
}

extension IsoDuration on String {
  String get readableDuration {
    final match = RegExp(r'^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$').firstMatch(this);
    if (match == null) return this;
    final hours = match.group(1);
    final minutes = match.group(2);
    final seconds = match.group(3);
    final result = [
      if (hours != null && hours != '0') '${hours}h',
      if (minutes != null && minutes != '0') '${minutes}m',
      if (hours == null && minutes == null && seconds != null) '${seconds}s',
    ].join(' ');
    return result.isEmpty ? '0m' : result;
  }
}

String _string(dynamic value) => value?.toString() ?? '';
int _int(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;
double _double(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0;
Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
