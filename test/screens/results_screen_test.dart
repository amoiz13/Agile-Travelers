import 'package:agile_travelers/main.dart';
import 'package:agile_travelers/models/resrobot_models.dart';
import 'package:agile_travelers/screens/results_screen.dart';
import 'package:agile_travelers/services/resrobot_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

// Fake service to isolate UI tests from network/JSON logic
class FakeResRobotService implements ResRobotService {
  bool shouldThrowError = false;

  final _dummyLocation1 = const Location(
    extId: '1',
    name: 'Stockholm',
    lat: 59.3,
    lon: 18.0,
    time: '10:00',
    date: '2026-09-06',
  );

  final _dummyLocation2 = const Location(
    extId: '2',
    name: 'Uppsala',
    lat: 59.8,
    lon: 17.6,
    time: '11:00',
    date: '2026-09-06',
  );

  @override
  Future<List<Location>> stopLookup(String query) async {
    if (query.toLowerCase().contains('stock')) return [_dummyLocation1];
    if (query.toLowerCase().contains('upps')) return [_dummyLocation2];
    return [];
  }

  @override
  Future<TripResponse> searchTrips({
    required String originId,
    required String destId,
    DateTime? date,
  }) async {
    if (shouldThrowError) {
      throw const ResRobotException('Fake API Error');
    }
    
    // Simulate network delay for loading state
    await Future.delayed(const Duration(milliseconds: 500));
    
    return TripResponse(
      trips: [
        Trip(
          duration: 'PT1H',
          transferCount: 0,
          origin: _dummyLocation1,
          destination: _dummyLocation2,
          legs: [
            Leg(
              id: '1',
              name: 'Train SJ',
              type: 'JNY',
              category: 'JST',
              duration: 'PT1H',
              origin: _dummyLocation1,
              destination: _dummyLocation2,
              products: [],
              notes: [],
            ),
          ],
        )
      ],
    );
  }

  // Not used but needed to fulfill implements contract
  @override
  String get apiKey => '';
  
  @override
  http.Client get client => throw UnimplementedError();
}

void main() {
  Widget createWidgetUnderTest(ResRobotService fakeService) {
    return ProviderScope(
      overrides: [
        resRobotProvider.overrideWithValue(fakeService),
      ],
      child: const MaterialApp(
        home: PlannerPage(),
      ),
    );
  }

  group('UI Layer Tests (Planner & Results Screen)', () {
    testWidgets('Shows loading indicator and then results on successful search', (WidgetTester tester) async {
      final fakeService = FakeResRobotService();
      await tester.pumpWidget(createWidgetUnderTest(fakeService));

      // 1. Fill Origin
      await tester.enterText(find.widgetWithText(TextField, 'Origin'), 'stock');
      await tester.pumpAndSettle(); // Wait for autocomplete debounce/results
      await tester.tap(find.text('Stockholm')); // Tap the dropdown item
      await tester.pumpAndSettle();

      // 2. Fill Destination
      await tester.enterText(find.widgetWithText(TextField, 'Destination'), 'upps');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uppsala'));
      await tester.pumpAndSettle();

      // 3. Tap Search
      await tester.tap(find.text('Search journeys'));
      
      // 4. Verify Loading State
      await tester.pump(); // Start the async gap
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 5. Verify Success State (Wait for delay to finish)
      await tester.pumpAndSettle(const Duration(seconds: 1));
      
      // The loading spinner should be gone
      expect(find.byType(CircularProgressIndicator), findsNothing);
      
      // ResultsScreen should be present
      expect(find.byType(ResultsScreen), findsOneWidget);
      
      // The trip duration (1h from PT1H) and cities should be visible
      expect(find.textContaining('Stockholm'), findsWidgets);
      expect(find.textContaining('Uppsala'), findsWidgets);
      expect(find.text('1h'), findsOneWidget); // Assuming PT1H formats to 1h
    });

    testWidgets('Shows error message on API failure', (WidgetTester tester) async {
      final fakeService = FakeResRobotService()..shouldThrowError = true;
      await tester.pumpWidget(createWidgetUnderTest(fakeService));

      // 1. Fill Origin & Destination
      await tester.enterText(find.widgetWithText(TextField, 'Origin'), 'stock');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stockholm'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Destination'), 'upps');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uppsala'));
      await tester.pumpAndSettle();

      // 2. Tap Search
      await tester.tap(find.text('Search journeys'));
      
      // 3. Verify Error State
      await tester.pumpAndSettle(); // Fast forward past the search resolution
      
      expect(find.text('Fake API Error'), findsOneWidget);
      // Results should not show any trip cards
      expect(find.text('1h'), findsNothing);
    });
    
    testWidgets('Search button is disabled if origin or destination is missing', (WidgetTester tester) async {
      final fakeService = FakeResRobotService();
      await tester.pumpWidget(createWidgetUnderTest(fakeService));

      // Just tap search without filling autocomplete
      await tester.tap(find.text('Search journeys'));
      await tester.pumpAndSettle();
      
      // Should show validation error on screen
      expect(find.text('Select both origin and destination stations.'), findsOneWidget);
    });
  });
}
