import 'package:flutter/material.dart';

import '../models/resrobot_models.dart';
import '../utils/co2_calculator.dart';

class TripDetailsScreen extends StatelessWidget {
  const TripDetailsScreen({required this.trip, super.key});

  final Trip trip;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Trip details')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${trip.origin.name} → ${trip.destination.name}',
                style: Theme.of(context).textTheme.titleLarge),
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
            const SizedBox(height: 16),
            for (final leg in trip.legs)
              Card(
                child: ListTile(
                  leading: Icon(leg.type == 'WALK'
                      ? Icons.directions_walk
                      : Icons.directions_transit),
                  title: Text(leg.name),
                  subtitle: Text(
                    '${leg.origin.time} → ${leg.destination.time}\n'
                    '${calculateLegCO2(leg)}',
                  ),
                  isThreeLine: true,
                ),
              ),
          ],
        ),
      );
}
