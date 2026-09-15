import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Scheduled trips, on the device only (`SharedPreferences`), like favourites and recent trips.
class ScheduledTripsRepository {
  ScheduledTripsRepository(this._prefs);
  final SharedPreferences _prefs;
  static const key = 'scheduledTrips.v1';

  List<ScheduledTrip> load() {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list.whereType<Map>().map((e) => ScheduledTrip.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<ScheduledTrip> trips) =>
      _prefs.setString(key, jsonEncode(trips.map((t) => t.toJson()).toList()));
}
