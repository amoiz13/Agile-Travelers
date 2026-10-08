import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'models/resrobot_models.dart';
import 'models/travel_preferences.dart';
import 'services/destination_discovery_service.dart';
import 'services/gemini_recommendation_service.dart';
import 'services/local_preferences_store.dart';
import 'services/network_unavailable_exception.dart';
import 'services/resrobot_service.dart';
import 'screens/interest_profile_screen.dart';
import 'screens/recommendations_screen.dart';
import 'screens/results_screen.dart';

final localPreferencesStoreProvider = Provider<LocalPreferencesStore>(
  (ref) => const LocalPreferencesStore(),
);

final resRobotProvider = Provider<ResRobotService>((ref) {
  return ResRobotService(
    apiKey: dotenv.env['RESROBOT_API_KEY'] ?? '',
    client: http.Client(),
  );
});

final geminiRecommendationProvider = Provider<GeminiRecommendationService>((
  ref,
) {
  return GeminiRecommendationService(
    apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
    client: http.Client(),
  );
});

final destinationDiscoveryProvider = Provider<DestinationDiscoveryService>((
  ref,
) {
  return DestinationDiscoveryService(
    gemini: ref.watch(geminiRecommendationProvider),
    resRobot: ref.watch(resRobotProvider),
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
    title: 'Agile Travelers',
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
            'Agile Travelers',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
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
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _originFocusNode = FocusNode();
  final _destinationFocusNode = FocusNode();
  final _preferenceController = TextEditingController();
  String? _destinationId;
  Location? _origin;
  List<Trip> _trips = const [];
  List<RecommendedJourney> _recommendedJourneys = const [];
  String? _recommendationMessage;
  List<String> _interests = const [];
  bool _searchedWithPreferences = false;
  bool _hasSearched = false;
  bool _loading = false;
  bool _loadingPreferences = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInterests();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _originFocusNode.dispose();
    _destinationFocusNode.dispose();
    _preferenceController.dispose();
    super.dispose();
  }

  Future<void> _loadInterests() async {
    try {
      final interests = await ref
          .read(localPreferencesStoreProvider)
          .loadInterests();
      if (mounted) setState(() => _interests = interests);
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not load travel interests: $error');
      }
    } finally {
      if (mounted) setState(() => _loadingPreferences = false);
    }
  }

  Future<void> _editInterests() async {
    final interests = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute<List<String>>(
        builder: (_) => InterestProfileScreen(
          store: ref.read(localPreferencesStoreProvider),
          initialInterests: _interests,
        ),
      ),
    );
    if (interests != null && mounted) {
      setState(() => _interests = interests);
    }
  }

  Future<void> _search() async {
    final origin = _origin;
    final preferenceText = _preferenceController.text.trim();
    final hasDestination = _destinationId != null;
    final preferencePrompt = [
      if (preferenceText.isNotEmpty) preferenceText,
      if (_interests.isNotEmpty)
        'My saved interests are: ${_interests.join(', ')}.',
    ].join('\n');
    final hasPreferences = preferencePrompt.isNotEmpty;
    if (origin == null || (!hasDestination && !hasPreferences)) {
      setState(
        () => _error =
            'Choose an origin and a destination, describe what you would '
            'like to explore, or add saved interests.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _trips = const [];
      _recommendedJourneys = const [];
      _recommendationMessage = null;
      _searchedWithPreferences = hasPreferences;
      _hasSearched = false;
    });

    var trips = <Trip>[];
    var recommendations = <RecommendedJourney>[];
    final errors = <String>[];
    var offline = false;

    if (hasDestination) {
      try {
        final response = await ref
            .read(resRobotProvider)
            .searchTrips(originId: origin.extId, destId: _destinationId!);
        trips = response.trips;
      } on NetworkUnavailableException {
        offline = true;
        errors.add(NetworkUnavailableException.message);
      } on ResRobotException catch (error) {
        errors.add(error.message);
      }
    }

    if (!offline && hasPreferences) {
      try {
        final discovery = await ref
            .read(destinationDiscoveryProvider)
            .discover(origin: origin, preferencePrompt: preferencePrompt);
        recommendations = discovery.journeys;
        _recommendationMessage = discovery.message;
      } on NetworkUnavailableException {
        errors.add(NetworkUnavailableException.message);
      } on GeminiRecommendationException catch (error) {
        errors.add(error.message);
      } on ResRobotException catch (error) {
        errors.add(error.message);
      }
    }

    if (mounted) {
      setState(() {
        _trips = trips;
        _recommendedJourneys = recommendations;
        _hasSearched = true;
        _error = errors.isEmpty ? null : errors.join('\n');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final resRobot = ref.read(resRobotProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agile Travelers'),
        actions: [
          IconButton(
            tooltip: 'Travel interests',
            onPressed: _loadingPreferences ? null : _editInterests,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    children: [
                      _StationAutocomplete(
                        label: 'Origin',
                        service: resRobot,
                        controller: _originController,
                        focusNode: _originFocusNode,
                        onSelected: (location) => setState(() {
                          _origin = location;
                        }),
                        onChanged: () => setState(() {
                          _origin = null;
                        }),
                      ),
                      const SizedBox(height: 12),
                      _StationAutocomplete(
                        label: 'Destination',
                        service: resRobot,
                        controller: _destinationController,
                        focusNode: _destinationFocusNode,
                        onSelected: (location) =>
                            setState(() => _destinationId = location.extId),
                        onChanged: () => setState(() => _destinationId = null),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Find a journey',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Search trains, buses, and walking legs across Sweden.',
                      ),
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Or describe the trip you have in mind',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Write naturally—anything from “a quiet beach '
                                'and seafood” to “a weekend of castles and '
                                'history.”',
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _preferenceController,
                                minLines: 2,
                                maxLines: 4,
                                maxLength: 500,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  hintText: 'What would you like to see or do?',
                                  border: OutlineInputBorder(),
                                  alignLabelWithHint: true,
                                  prefixIcon: Icon(Icons.auto_awesome),
                                ),
                              ),
                              if (_interests.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    'Saved interests can generate suggestions '
                                    'without a written description.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: _loadingPreferences
                                      ? null
                                      : _editInterests,
                                  icon: const Icon(Icons.tune),
                                  label: Text(
                                    _interests.isEmpty
                                        ? 'Set optional saved interests'
                                        : 'Edit saved interests',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _loading ? null : _search,
                        icon: _loading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.search),
                        label: Text(
                          _loading ? 'Finding journeys...' : 'Find journeys',
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (_hasSearched && _destinationId != null) ...[
                        Text(
                          'Routes to your destination',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        if (_trips.isNotEmpty)
                          ResultsScreen(trips: _trips)
                        else if (_error == null)
                          const Text(
                            'No routes were found for that destination.',
                          ),
                      ],
                      if (_hasSearched && _searchedWithPreferences) ...[
                        const SizedBox(height: 16),
                        RecommendedJourneysSection(
                          journeys: _recommendedJourneys,
                        ),
                        if (_recommendationMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _recommendationMessage!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                      ],
                      if (!_hasSearched && !_loading)
                        Text(
                          'Choose a destination, describe your interests, or '
                          'use your saved interests.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StationAutocomplete extends StatelessWidget {
  const _StationAutocomplete({
    required this.label,
    required this.service,
    required this.controller,
    required this.focusNode,
    required this.onSelected,
    required this.onChanged,
  });

  final String label;
  final ResRobotService service;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<Location> onSelected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => RawAutocomplete<Location>(
    textEditingController: controller,
    focusNode: focusNode,
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
