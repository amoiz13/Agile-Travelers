import 'package:shared_preferences/shared_preferences.dart';

class LocalPreferencesStore {
  const LocalPreferencesStore();

  static const _interestsKey = 'travel_interests';
  static const _seatAmenitiesKey = 'seat_amenities';
  static const _selectedSeatKey = 'selected_demo_seat';

  Future<List<String>> loadInterests() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_interestsKey) ?? const [];
  }

  Future<void> saveInterests(List<String> interests) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setStringList(_interestsKey, interests);
    if (!saved) {
      throw StateError('Could not save travel interests on this device.');
    }
  }

  Future<List<String>> loadSeatAmenities() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_seatAmenitiesKey) ?? const [];
  }

  Future<void> saveSeatAmenities(List<String> amenities) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setStringList(_seatAmenitiesKey, amenities);
    if (!saved) {
      throw StateError('Could not save seat preferences on this device.');
    }
  }

  Future<String?> loadSelectedSeat() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_selectedSeatKey);
  }

  Future<void> saveSelectedSeat(String? seat) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = seat == null
        ? await preferences.remove(_selectedSeatKey)
        : await preferences.setString(_selectedSeatKey, seat);
    if (!saved) {
      throw StateError('Could not save the seat preference on this device.');
    }
  }
}
