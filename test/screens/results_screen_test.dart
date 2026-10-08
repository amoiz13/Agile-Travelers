import 'dart:convert';

import 'package:agile_travelers/main.dart';
import 'package:agile_travelers/models/resrobot_models.dart';
import 'package:agile_travelers/screens/results_screen.dart';
import 'package:agile_travelers/services/gemini_recommendation_service.dart';
import 'package:agile_travelers/services/network_unavailable_exception.dart';
import 'package:agile_travelers/services/resrobot_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Fake service to isolate UI tests from network/JSON logic
class FakeResRobotService implements ResRobotService {
  bool shouldThrowError = false;
  bool shouldThrowOffline = false;

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
    if (shouldThrowOffline) {
      throw const NetworkUnavailableException();
    }
    if (shouldThrowError) {
      throw const ResRobotException(
        'We couldn’t load journey information. Please try again.',
      );
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
        ),
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
  void useLargeViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget createWidgetUnderTest(
    ResRobotService fakeService, {
    String expectedPromptText = 'quiet lakeside walk',
  }) {
    return ProviderScope(
      overrides: [
        resRobotProvider.overrideWithValue(fakeService),
        geminiRecommendationProvider.overrideWithValue(
          GeminiRecommendationService(
            apiKey: 'test-key',
            client: MockClient((request) async {
              expect(request.body, contains(expectedPromptText));
              return http.Response(
                jsonEncode({
                  'candidates': [
                    {
                      'content': {
                        'parts': [
                          {
                            'text': jsonEncode({
                              'relevant': true,
                              'message': '',
                              'destinations': [
                                {
                                  'destination': 'Uppsala',
                                  'reason': 'A peaceful lakeside walk.',
                                },
                              ],
                            }),
                          },
                        ],
                      },
                    },
                  ],
                }),
                200,
              );
            }),
          ),
        ),
      ],
      child: const MaterialApp(home: PlannerPage()),
    );
  }

  group('UI Layer Tests (Planner & Results Screen)', () {
    testWidgets(
      'Shows loading indicator and then results on successful search',
      (WidgetTester tester) async {
        useLargeViewport(tester);
        final fakeService = FakeResRobotService();
        await tester.pumpWidget(createWidgetUnderTest(fakeService));

        // 1. Fill Origin
        await tester.enterText(
          find.widgetWithText(TextField, 'Origin'),
          'stock',
        );
        await tester.pumpAndSettle(); // Wait for autocomplete debounce/results
        await tester.tap(find.text('Stockholm')); // Tap the dropdown item
        await tester.pumpAndSettle();

        // 2. Fill Destination
        await tester.enterText(
          find.widgetWithText(TextField, 'Destination'),
          'upps',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Uppsala'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField).last,
          'I want a quiet lakeside walk.',
        );

        // 3. Tap Search
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Find journeys'));

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
        expect(find.text('Recommended for your interests'), findsOneWidget);
      },
    );

    testWidgets('Shows a friendly message when journey search fails', (
      WidgetTester tester,
    ) async {
      useLargeViewport(tester);
      final fakeService = FakeResRobotService()..shouldThrowError = true;
      await tester.pumpWidget(createWidgetUnderTest(fakeService));

      // 1. Fill Origin & Destination
      await tester.enterText(find.widgetWithText(TextField, 'Origin'), 'stock');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stockholm'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Destination'),
        'upps',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uppsala'));
      await tester.pumpAndSettle();

      // 2. Tap Search
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Find journeys'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Find journeys'));

      // 3. Verify Error State
      await tester.pumpAndSettle(); // Fast forward past the search resolution

      expect(
        find.textContaining('We couldn’t load journey information'),
        findsOneWidget,
      );
      // Results should not show any trip cards
      expect(find.text('1h'), findsNothing);
    });

    testWidgets('Shows a specific message when searching without internet', (
      WidgetTester tester,
    ) async {
      useLargeViewport(tester);
      final fakeService = FakeResRobotService()..shouldThrowOffline = true;
      await tester.pumpWidget(createWidgetUnderTest(fakeService));

      await tester.enterText(find.widgetWithText(TextField, 'Origin'), 'stock');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stockholm'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Destination'),
        'upps',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uppsala'));
      await tester.pumpAndSettle();
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Find journeys'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Find journeys'));
      await tester.pumpAndSettle();

      expect(find.text(NetworkUnavailableException.message), findsOneWidget);
      expect(find.textContaining('ResRobot'), findsNothing);
      expect(find.textContaining('API'), findsNothing);
    });

    testWidgets('search requires an origin and a destination or interests', (
      WidgetTester tester,
    ) async {
      useLargeViewport(tester);
      final fakeService = FakeResRobotService();
      await tester.pumpWidget(createWidgetUnderTest(fakeService));

      // Just tap search without filling autocomplete
      await tester.scrollUntilVisible(
        find.text('Find journeys'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Find journeys'));
      await tester.pumpAndSettle();

      // Should show validation error on screen
      expect(find.textContaining('Choose an origin'), findsOneWidget);
    });

    testWidgets('selected interests generate suggestions without typed text', (
      tester,
    ) async {
      useLargeViewport(tester);
      SharedPreferences.setMockInitialValues({});
      final fakeService = FakeResRobotService();
      await tester.pumpWidget(
        createWidgetUnderTest(
          fakeService,
          expectedPromptText: 'Nature & scenery',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set optional saved interests'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nature & scenery'));
      await tester.tap(find.text('Save interests'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Origin'), 'stock');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stockholm'));
      await tester.pumpAndSettle();
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Find journeys'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Find journeys'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Routes to your destination'), findsNothing);
      expect(find.text('Picked for you'), findsOneWidget);
      expect(find.text('Recommended for your interests'), findsOneWidget);
      expect(find.textContaining('Uppsala'), findsWidgets);
    });

    testWidgets('origin and destination text persist after scrolling', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fakeService = FakeResRobotService();
      await tester.pumpWidget(createWidgetUnderTest(fakeService));

      await tester.enterText(find.widgetWithText(TextField, 'Origin'), 'stock');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stockholm'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Destination'),
        'upps',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uppsala'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Origin'), findsNothing);
      expect(find.widgetWithText(TextField, 'Destination'), findsNothing);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 600));
      await tester.pumpAndSettle();

      final originField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Origin'),
      );
      final destinationField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Destination'),
      );
      expect(originField.controller!.text, 'Stockholm');
      expect(destinationField.controller!.text, 'Uppsala');
    });
  });
}
