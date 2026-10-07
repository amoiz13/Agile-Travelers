import 'package:flutter/material.dart';

import '../models/resrobot_models.dart';
import '../services/local_preferences_store.dart';
import '../utils/co2_calculator.dart';
import 'seat_customization_screen.dart';

class TripDetailsScreen extends StatelessWidget {
  const TripDetailsScreen({required this.trip, super.key});

  final Trip trip;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Trip details')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${trip.origin.name} → ${trip.destination.name}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.eco, color: Colors.green, size: 20),
            const SizedBox(width: 6),
            Text(
              'Total: ${calculateTripCO2(trip)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SeatCustomizationScreen(
                store: const LocalPreferencesStore(),
                tripSummary: '${trip.origin.name} → ${trip.destination.name}',
              ),
            ),
          ),
          icon: const Icon(Icons.airline_seat_recline_extra),
          label: const Text('Set seat comfort preferences'),
        ),
        const SizedBox(height: 8),
        Text(
          'Comfort settings are a local prototype and do not reserve a seat.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        for (final leg in trip.legs)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      leg.type == 'WALK'
                          ? Icons.directions_walk
                          : Icons.directions_transit,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          leg.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${leg.origin.name} → ${leg.destination.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${leg.origin.time} → ${leg.destination.time}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Distance: ${formatDistance(calculateLegDistanceKm(leg))} • '
                          '${calculateLegCO2(leg)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
