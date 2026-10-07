import 'package:flutter/material.dart';

import '../models/travel_preferences.dart';
import '../services/local_preferences_store.dart';

class InterestProfileScreen extends StatefulWidget {
  const InterestProfileScreen({
    required this.store,
    required this.initialInterests,
    super.key,
  });

  final LocalPreferencesStore store;
  final List<String> initialInterests;

  @override
  State<InterestProfileScreen> createState() => _InterestProfileScreenState();
}

class _InterestProfileScreenState extends State<InterestProfileScreen> {
  late final Set<String> _selected = {...widget.initialInterests};
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final interests = _selected.toList()..sort();
      await widget.store.saveInterests(interests);
      if (mounted) Navigator.of(context).pop(interests);
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not save preferences: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Travel interests')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'What do you enjoy?',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose a few themes. Gemini will use them to suggest '
          'destinations, then ResRobot checks for actual journeys.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final interest in TravelPreferences.availableInterests)
              FilterChip(
                label: Text(interest),
                selected: _selected.contains(interest),
                onSelected: _saving
                    ? null
                    : (selected) => setState(() {
                        if (selected) {
                          _selected.add(interest);
                        } else {
                          _selected.remove(interest);
                        }
                      }),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save interests'),
        ),
      ],
    ),
  );
}
