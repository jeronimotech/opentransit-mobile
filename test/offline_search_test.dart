library;

/// Finding a place with no network.
///
/// Without this the offline planner was unreachable: the geocoder is a network call, so typing an
/// origin answered "cannot reach the server" — with an engine behind it that plans a cross-town
/// Bogotá trip in 88 ms. Found by a rider on a phone, not by any test here.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/offline/offline_bundle.dart';
import 'package:opentransit_mobile/core/offline/offline_plan.dart';

final _header = OfflineHeader.parse(jsonEncode({
  'v': 1,
  'city': 'bogota',
  'routes': [], 'headsigns': [], 'services': [], 'serviceExceptions': [],
  'stops': [
    {'id': 'S1', 'name': 'Portal Suba', 'lat': 4.7430, 'lon': -74.0940, 'type': 1, 'code': '08000'},
    {'id': 'S2', 'name': 'Portal Sur', 'lat': 4.5955, 'lon': -74.1711, 'type': 1},
    {'id': 'S3', 'name': 'Av Jiménez', 'lat': 4.6012, 'lon': -74.0718, 'type': 0},
    {'id': 'S4', 'name': 'Transversal Portales', 'lat': 4.6500, 'lon': -74.0800, 'type': 0},
  ],
  'stats': {'departures': 0},
}));

List<String> _names(List<GeocodeResult> r) => [for (final x in r) x.name];

void main() {
  group('ranking', () {
    test('a name that starts with the query comes before one that contains it', () {
      // Someone typing "porta" wants Portal Suba, not Transversal Portales.
      final r = offlineSearchStops(_header, 'porta', cityId: 'bogota');
      expect(_names(r).first, startsWith('Portal'));
      expect(_names(r).last, 'Transversal Portales');
    });

    test('an exact stop code wins over any name', () {
      // A code is the most deliberate thing a rider can type.
      final r = offlineSearchStops(_header, '08000', cityId: 'bogota');
      expect(_names(r).first, 'Portal Suba');
    });

    test('nearer wins when the match is equally good', () {
      final nearSuba = offlineSearchStops(_header, 'portal',
          cityId: 'bogota', near: const LatLng(4.7400, -74.0900));
      expect(_names(nearSuba).first, 'Portal Suba');
      final nearSur = offlineSearchStops(_header, 'portal',
          cityId: 'bogota', near: const LatLng(4.5900, -74.1700));
      expect(_names(nearSur).first, 'Portal Sur');
    });
  });

  group('typing', () {
    test('accents are not required', () {
      // "jimenez" has to find "Av Jiménez"; nobody reaches for the accent on a bus.
      expect(_names(offlineSearchStops(_header, 'jimenez', cityId: 'bogota')), ['Av Jiménez']);
      expect(_names(offlineSearchStops(_header, 'JIMÉNEZ', cityId: 'bogota')), ['Av Jiménez']);
    });

    test('an empty or blank query finds nothing rather than everything', () {
      expect(offlineSearchStops(_header, '', cityId: 'bogota'), isEmpty);
      expect(offlineSearchStops(_header, '   ', cityId: 'bogota'), isEmpty);
    });

    test('no match is empty', () {
      expect(offlineSearchStops(_header, 'zzzz', cityId: 'bogota'), isEmpty);
    });
  });

  group('what comes back', () {
    test('is a stop the planner can use, scoped to the city', () {
      final r = offlineSearchStops(_header, 'suba', cityId: 'bogota').single;
      expect(r.stopId, 'bogota:S1');
      expect(r.id, 'bogota:S1');
      expect(r.source, 'gtfs');
      expect(r.type, 'station');
      expect(r.position.lat, closeTo(4.7430, 1e-9));
    });

    test('a plain stop is a stop and not a station', () {
      expect(offlineSearchStops(_header, 'jimenez', cityId: 'bogota').single.type, 'stop');
    });

    test('never claims to be an address', () {
      // The online geocoder also knows streets and places; none of that is in the bundle, and the
      // screen says so. Labelling a stop as an address would be the quieter lie.
      final r = offlineSearchStops(_header, 'portal', cityId: 'bogota');
      expect(r.every((x) => x.type == 'stop' || x.type == 'station'), isTrue);
      expect(r.every((x) => x.source == 'gtfs'), isTrue);
    });

    test('the limit is honoured', () {
      expect(offlineSearchStops(_header, 'a', cityId: 'bogota', limit: 2).length, lessThanOrEqualTo(2));
    });
  });
}
