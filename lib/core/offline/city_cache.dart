import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// The last city list the API gave us, kept on disk so the app can start without a network.
///
/// This is not an optimisation. Every screen needs its city's configuration — colours, components,
/// feature flags, the planner's modes — and `citiesProvider` had only one source, the network. So
/// underground the app sat on a spinner forever and a rider could never reach the downloaded
/// timetable they had deliberately installed. Found by pulling the network on a real phone.
///
/// Deliberately not expiring. A stale city list is a few wrong colours; no city list is an app that
/// does not open. The network copy replaces it on every successful fetch, so it is never stale for
/// long, and nothing here is a substitute for being online — only for not being stranded.
class CityCache {
  CityCache({Directory? directory}) : _dir = directory;

  Directory? _dir;

  Future<File> _file() async {
    final d = _dir ??= await getApplicationDocumentsDirectory();
    return File('${d.path}/cities.json');
  }

  Future<void> save(List<Map<String, dynamic>> raw) async {
    try {
      await (await _file()).writeAsString(jsonEncode(raw));
    } on Object {
      // A cache that cannot be written must not break the request that filled it.
    }
  }

  Future<List<City>?> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final raw = jsonDecode(await f.readAsString());
      if (raw is! List || raw.isEmpty) return null;
      return [
        for (final c in raw)
          if (c is Map) City.fromJson(Map<String, dynamic>.from(c)),
      ];
    } on Object {
      // Unreadable or written by an older format: treat as absent rather than crash on launch.
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } on Object {
      // nothing to do
    }
  }
}
