import 'package:flutter/material.dart';

import '../models/resrobot_models.dart';
import '../utils/co2_calculator.dart';
import 'trip_details_screen.dart';

enum TripSort { departure, duration, transfers, emissions }

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({required this.trips, super.key});

  final List<Trip> trips;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  TripSort _sort = TripSort.departure;

  List<Trip> get _sortedTrips {
    final trips = [...widget.trips];
    trips.sort((a, b) {
      switch (_sort) {
        case TripSort.departure:
          return _timeValue(a.origin.time).compareTo(_timeValue(b.origin.time));
        case TripSort.duration:
          return _durationValue(a.duration).compareTo(_durationValue(b.duration));
        case TripSort.transfers:
          return a.transferCount.compareTo(b.transferCount);
        case TripSort.emissions:
          return calculateTripCO2Grams(a).compareTo(calculateTripCO2Grams(b));
      }
    });
    return trips;
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.trips.isNotEmpty)
            DropdownButtonFormField<TripSort>(
              initialValue: _sort,
              decoration: const InputDecoration(
                labelText: 'Sort journeys by',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.sort),
              ),
              items: const [
                DropdownMenuItem(
                  value: TripSort.departure,
                  child: Text('Departure time'),
                ),
                DropdownMenuItem(
                  value: TripSort.duration,
                  child: Text('Shortest journey'),
                ),
                DropdownMenuItem(
                  value: TripSort.transfers,
                  child: Text('Fewest transfers'),
                ),
                DropdownMenuItem(
                  value: TripSort.emissions,
                  child: Text('Lowest CO2 emissions'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _sort = value);
              },
            ),
          const SizedBox(height: 12),
          for (final trip in _sortedTrips)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(trip.duration.readableDuration),
                subtitle: Text(
                    '${trip.origin.name} → ${trip.destination.name} • ${trip.transferCount} transfers'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TripDetailsScreen(trip: trip),
                  ),
                ),
              ),
            ),
        ],
      );
}

int _timeValue(String value) {
  final parts = value.split(':').map(int.tryParse).toList();
  if (parts.length < 2 || parts[0] == null || parts[1] == null) return 0;
  return parts[0]! * 60 + parts[1]!;
}

int _durationValue(String value) {
  final match = RegExp(r'^PT(?:(\d+)H)?(?:(\d+)M)?').firstMatch(value);
  if (match == null) return 0;
  return (int.tryParse(match.group(1) ?? '0') ?? 0) * 60 +
      (int.tryParse(match.group(2) ?? '0') ?? 0);
}
