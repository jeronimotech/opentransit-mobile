library;

/// Starting the app with no network.
///
/// Every screen needs its city's configuration, and `citiesProvider` had only one source. So
/// underground the app sat on a spinner forever and the downloaded timetable — the whole point of
/// item 6 — was unreachable. A real phone with the network pulled found it; nothing here had.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/offline/city_cache.dart';

Map<String, dynamic> _city(String id, String name) => {
      'id': id,
      'name': name,
      'country': 'CO',
      'timezone': 'America/Bogota',
      'locale': 'es',
      'center': {'lat': 4.65, 'lon': -74.08},
      'bbox': [-74.45, 3.95, -73.85, 4.90],
      'defaultZoom': 12,
      'modes': ['WALK', 'BUS'],
      'branding': {'primaryColor': '#D32F2F'},
      'features': {'realtimeVehicles': true},
      'agencies': [],
    };

void main() {
  late Directory tmp;
  late CityCache cache;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('city_cache');
    cache = CityCache(directory: tmp);
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('nothing cached reads as nothing, not as an empty city list', () async {
    // The difference matters: null means "ask the network", an empty list would mean "there are no
    // cities", and the second shows a rider an empty picker.
    expect(await cache.load(), isNull);
  });

  test('a saved list comes back with the configuration screens need', () async {
    await cache.save([_city('bogota', 'Bogotá'), _city('roma', 'Roma')]);
    final back = await cache.load();
    expect(back!.map((c) => c.id), ['bogota', 'roma']);
    expect(back.first.name, 'Bogotá');
    expect(back.first.primaryColor, '#D32F2F');
    expect(back.first.features.realtimeVehicles, isTrue);
  });

  test('saving again replaces, so the cache cannot grow or go stale in layers', () async {
    await cache.save([_city('bogota', 'Bogotá')]);
    await cache.save([_city('roma', 'Roma'), _city('lisboa', 'Lisboa')]);
    expect((await cache.load())!.map((c) => c.id), ['roma', 'lisboa']);
  });

  test('an unreadable cache reads as absent rather than crashing on launch', () async {
    await cache.save([_city('bogota', 'Bogotá')]);
    await File('${tmp.path}/cities.json').writeAsString('{not json');
    // This file is read on the way to the first frame. Throwing here is a boot loop.
    expect(await cache.load(), isNull);
  });

  test('an empty saved list is not a usable cache', () async {
    await cache.save(const []);
    expect(await cache.load(), isNull);
  });

  test('clearing leaves nothing behind', () async {
    await cache.save([_city('bogota', 'Bogotá')]);
    await cache.clear();
    expect(await cache.load(), isNull);
  });
}
