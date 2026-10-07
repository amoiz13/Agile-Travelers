import 'package:agile_travelers/screens/seat_customization_screen.dart';
import 'package:agile_travelers/services/local_preferences_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('selecting a demo seat reveals comfort controls', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SeatCustomizationScreen(
          store: LocalPreferencesStore(),
          tripSummary: 'Stockholm → Uppsala',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose a demo seat'), findsOneWidget);
    expect(
      find.text('Comfort options for Coach 04 • Seat 04-21A'),
      findsNothing,
    );

    await tester.tap(find.text('04-21A'));
    await tester.pumpAndSettle();

    expect(
      find.text('Comfort options for Coach 04 • Seat 04-21A'),
      findsOneWidget,
    );
    for (final amenity in [
      'Recline functionality',
      'Seat ventilation',
      'Adjustable headrest',
      'Lumbar support',
    ]) {
      await tester.scrollUntilVisible(
        find.text(amenity),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(amenity), findsOneWidget);
    }
    expect(find.textContaining('does not reserve a seat'), findsOneWidget);
  });
}
