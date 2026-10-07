import 'package:agile_travelers/services/local_preferences_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores and reloads interests and seat comfort choices', () async {
    const store = LocalPreferencesStore();

    await store.saveInterests(const ['History & heritage']);
    await store.saveSeatAmenities(const [
      'Recline functionality',
      'Lumbar support',
    ]);
    await store.saveSelectedSeat('04-21A');

    expect(await store.loadInterests(), ['History & heritage']);
    expect(await store.loadSeatAmenities(), [
      'Recline functionality',
      'Lumbar support',
    ]);
    expect(await store.loadSelectedSeat(), '04-21A');
  });
}
