import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'models/resrobot_models.dart';
import 'services/resrobot_service.dart';
import 'screens/results_screen.dart';

final resRobotProvider = Provider<ResRobotService>((ref) {
  return ResRobotService(
    apiKey: dotenv.env['RESROBOT_API_KEY'] ?? '',
    client: http.Client(),
  );
});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', mergeWith: const {});
  runApp(const ProviderScope(child: TransitPlannerApp()));
}

class TransitPlannerApp extends StatelessWidget {
  const TransitPlannerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Agile Travellers',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff006b5e)),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const PlannerPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.travel_explore,
                size: 88,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Agile Travellers',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              const Text('Plan smarter journeys across Sweden'),
            ],
          ),
        ),
      );
}

class PlannerPage extends ConsumerStatefulWidget {
  const PlannerPage({super.key});

  @override
  ConsumerState<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends ConsumerState<PlannerPage> {
  String? _originId;
  String? _destinationId;
  List<Trip> _trips = const [];
  bool _loading = false;
  String? _error;

  Future<void> _search() async {
    if (_originId == null || _destinationId == null) {
      setState(() => _error = 'Select both origin and destination stations.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(resRobotProvider).searchTrips(
        originId: _originId!,
            destId: _destinationId!,
          );
      if (mounted) setState(() => _trips = response.trips);
    } on ResRobotException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Agile Travellers')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('Find a journey',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text(
                    'Search trains, buses, and walking legs across Sweden.'),
                const SizedBox(height: 24),
                _StationAutocomplete(
                  label: 'Origin',
                  service: ref.read(resRobotProvider),
                  onSelected: (location) =>
                      setState(() => _originId = location.extId),
                  onChanged: () => setState(() => _originId = null),
                ),
                const SizedBox(height: 12),
                _StationAutocomplete(
                  label: 'Destination',
                  service: ref.read(resRobotProvider),
                  onSelected: (location) =>
                      setState(() => _destinationId = location.extId),
                  onChanged: () => setState(() => _destinationId = null),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loading ? null : _search,
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: const Text('Search journeys'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                ResultsScreen(trips: _trips),
                if (!_loading && _trips.isEmpty && _error == null)
                  const Text('Your journey options will appear here.'),
              ],
            ),
          ),
        ),
      );
}

class _StationAutocomplete extends StatelessWidget {
  const _StationAutocomplete({
    required this.label,
    required this.service,
    required this.onSelected,
    required this.onChanged,
  });

  final String label;
  final ResRobotService service;
  final ValueChanged<Location> onSelected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Autocomplete<Location>(
        displayStringForOption: (location) => location.name,
        optionsBuilder: (value) async {
          if (value.text.trim().length < 2) return const <Location>[];
          return service.stopLookup(value.text);
        },
        onSelected: (location) {
          onSelected(location);
        },
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 600),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final location = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(location.name),
                    onTap: () => onSelected(location),
                  );
                },
              ),
            ),
          ),
        ),
        fieldViewBuilder: (context, fieldController, focusNode, onSubmitted) {
          return TextField(
            controller: fieldController,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: label,
              hintText: 'Search for a station',
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.place_outlined),
            ),
            onSubmitted: (_) {
              onSubmitted();
              focusNode.unfocus();
            },
            onChanged: (_) => onChanged(),
          );
        },
      );
}
