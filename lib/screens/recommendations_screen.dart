import 'package:flutter/material.dart';

import '../models/travel_preferences.dart';
import '../models/resrobot_models.dart';
import 'trip_details_screen.dart';

class RecommendationsScreen extends StatelessWidget {
  const RecommendationsScreen({
    required this.origin,
    required this.journeys,
    super.key,
  });

  final Location origin;
  final List<RecommendedJourney> journeys;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ideas for your next trip')),
    body: journeys.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No suggested destinations had a matching ResRobot '
                'journey from this station. Try another origin or '
                'update your interests.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Starting from ${origin.name}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Suggestions are AI-generated; journey details below '
                'come from ResRobot.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final recommendation in journeys)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.explore_outlined),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(recommendation.stationName),
                        const SizedBox(height: 4),
                        const _RecommendedBadge(),
                      ],
                    ),
                    subtitle: Text(
                      '${recommendation.idea.reason}\n'
                      '${recommendation.trip.duration.readableDuration} '
                      '• ${recommendation.trip.transferCount} transfers',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            TripDetailsScreen(trip: recommendation.trip),
                      ),
                    ),
                  ),
                ),
            ],
          ),
  );
}

class RecommendedJourneysSection extends StatelessWidget {
  const RecommendedJourneysSection({required this.journeys, super.key});

  final List<RecommendedJourney> journeys;

  @override
  Widget build(BuildContext context) {
    if (journeys.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Picked for you', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'AI recommendations with journey details checked by ResRobot.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        for (final recommendation in journeys)
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TripDetailsScreen(trip: recommendation.trip),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          recommendation.stationName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const _RecommendedBadge(),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(recommendation.idea.reason),
                    const SizedBox(height: 8),
                    Text(
                      '${recommendation.trip.duration.readableDuration} • '
                      '${recommendation.trip.transferCount} transfers',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RecommendedBadge extends StatelessWidget {
  const _RecommendedBadge();

  @override
  Widget build(BuildContext context) => Chip(
    avatar: const Icon(Icons.auto_awesome, size: 16),
    label: const Text('Recommended for your interests'),
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    labelStyle: Theme.of(context).textTheme.labelSmall,
  );
}
