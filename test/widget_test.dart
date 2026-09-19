import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:agile_travellers/main.dart';

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'RESROBOT_API_KEY=test');
  });

  testWidgets('planner renders search form', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: PlannerPage())),
    );

    expect(find.text('Agile Travellers'), findsOneWidget);
    expect(find.text('Search journeys'), findsOneWidget);
    expect(find.text('Your journey options will appear here.'), findsOneWidget);
  });
}
