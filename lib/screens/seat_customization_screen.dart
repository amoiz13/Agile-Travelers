import 'package:flutter/material.dart';

import '../services/local_preferences_store.dart';

class SeatCustomizationScreen extends StatefulWidget {
  const SeatCustomizationScreen({
    required this.store,
    required this.tripSummary,
    super.key,
  });

  final LocalPreferencesStore store;
  final String tripSummary;

  @override
  State<SeatCustomizationScreen> createState() =>
      _SeatCustomizationScreenState();
}

class _SeatCustomizationScreenState extends State<SeatCustomizationScreen> {
  static const _amenities = [
    ('Recline functionality', Icons.airline_seat_recline_extra),
    ('Seat ventilation', Icons.air),
    ('Adjustable headrest', Icons.event_seat),
    ('Lumbar support', Icons.accessibility_new),
  ];
  static const _demoSeats = [
    '04-21A',
    '04-21B',
    '04-21C',
    '04-21D',
    '04-22A',
    '04-22B',
    '04-22C',
    '04-22D',
  ];

  Set<String> _selected = {};
  String? _selectedSeat;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = await widget.store.loadSeatAmenities();
      final seat = await widget.store.loadSelectedSeat();
      if (mounted) {
        setState(() {
          _selected = saved.toSet();
          _selectedSeat = seat;
        });
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not load preferences: $error');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.saveSelectedSeat(_selectedSeat);
      await widget.store.saveSeatAmenities(_selected.toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comfort preferences saved on this device.'),
          ),
        );
      }
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
    appBar: AppBar(title: const Text('Seat comfort')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Comfort preferences',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(widget.tripSummary),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.airline_seat_recline_extra,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your preferred seat setup',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text('Choose what makes your trip more comfortable'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Choose a demo seat',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Coach 04 • Sample layout (not live vehicle inventory)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final seat in _demoSeats)
              ChoiceChip(
                label: Text(seat),
                selected: _selectedSeat == seat,
                onSelected: _loading || _saving
                    ? null
                    : (selected) => setState(
                        () => _selectedSeat = selected ? seat : null,
                      ),
              ),
          ],
        ),
        if (_selectedSeat == null) ...[
          const SizedBox(height: 16),
          const Text('Select a demo seat to see its comfort options.'),
        ] else ...[
          const SizedBox(height: 16),
          Text(
            'Comfort options for Coach 04 • Seat $_selectedSeat',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Prototype options only; the operator has not confirmed '
            'availability for this journey.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          for (final (amenity, icon) in _amenities)
            SwitchListTile(
              secondary: Icon(icon),
              title: Text(amenity),
              value: _selected.contains(amenity),
              onChanged: _loading || _saving
                  ? null
                  : (enabled) => setState(() {
                      if (enabled) {
                        _selected.add(amenity);
                      } else {
                        _selected.remove(amenity);
                      }
                    }),
            ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading || _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Save comfort preferences'),
        ),
        const SizedBox(height: 12),
        Text(
          'Prototype only: these choices are saved on this device. '
          'ResRobot does not provide seat inventory, so this does not '
          'reserve a seat or confirm that an operator offers these features.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
