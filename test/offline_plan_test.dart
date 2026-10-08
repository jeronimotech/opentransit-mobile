library;

/// Turning an offline journey into something the existing screens can draw, and the walking links
/// the pattern index does not carry.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/offline/offline_bundle.dart';
import 'package:opentransit_mobile/core/offline/offline_patterns.dart';
import 'package:opentransit_mobile/core/offline/offline_plan.dart';
import 'package:opentransit_mobile/core/offline/offline_router.dart';

/// A, B and C in a line ~250 m apart; D sits 80 m from C, across the street.
final _header = OfflineHeader.parse(jsonEncode({
  'v': 1,
  'city': 'testville',
  'routes': [],
  'headsigns': [],
  'services': [],
  'serviceExceptions': [],
  'stops': [
    {'id': 'A', 'name': 'Portal A', 'lat': 4.6000, 'lon': -74.0800, 'type': 0},
    {'id': 'B', 'name': 'Calle B', 'lat': 4.6022, 'lon': -74.0800, 'type': 0},
    {'id': 'C', 'name': 'Centro C', 'lat': 4.6045, 'lon': -74.0800, 'type': 0},
    {'id': 'D', 'name': 'Plaza D', 'lat': 4.6045, 'lon': -74.0793, 'type': 0},
  ],
  'stats': {'departures': 0},
}));

final _patterns = OfflinePatterns.parse(jsonEncode({
  'city': 'testville',
  'stops': ['A', 'B', 'C', 'D'],
  'routes': ['G12'],
  'headsigns': ['Norte'],
  'services': ['WK'],
  'patterns': [
    {'r': 0, 'h': 0, 's': [0, 1, 2], 't': [[0, [480, 490, 500]]]},
  ],
}));

void main() {
  group('walking links', () {
    test('nearby stops are linked, distant ones are not', () {
      final f = buildFootpaths(_header, _patterns.stops, radiusMetres: 150);
      // D is ~80 m from C.
      expect(f[2].map((x) => x.stop), contains(3));
      expect(f[3].map((x) => x.stop), contains(2));
      // A to C is ~500 m, well outside.
      expect(f[0].map((x) => x.stop), isNot(contains(2)));
    });

    test('a wider radius links more, and the link is symmetric', () {
      final f = buildFootpaths(_header, _patterns.stops, radiusMetres: 600);
      expect(f[0].map((x) => x.stop), contains(2));
      expect(f[2].map((x) => x.stop), contains(0));
    });

    test('never free: two stops a metre apart still cost a minute', () {
      // A zero-cost hop would let a search chain stops for nothing and invent a journey nobody
      // can walk.
      final f = buildFootpaths(_header, _patterns.stops, radiusMetres: 600);
      expect(f.expand((l) => l).every((x) => x.minutes >= 1), isTrue);
    });

    test('a stop the board bundle does not know is skipped, not crashed on', () {
      final f = buildFootpaths(_header, ['A', 'GHOST', 'C'], radiusMetres: 600);
      expect(f.length, 3);
      expect(f[1], isEmpty);
    });

    test('no stop links to itself', () {
      final f = buildFootpaths(_header, _patterns.stops, radiusMetres: 5000);
      for (var i = 0; i < f.length; i++) {
        expect(f[i].map((x) => x.stop), isNot(contains(i)));
      }
    });
  });

  group('the plan a rider sees', () {
    PlanResponse plan() {
      final journeys = planOffline(
        data: _patterns,
        originStops: {0},
        destinationStops: {2},
        departAfterMinute: 470,
        runningServices: {0},
        footpaths: buildFootpaths(_header, _patterns.stops, radiusMetres: 150),
      );
      return offlinePlanResponse(
        data: _patterns, header: _header, journeys: journeys,
        from: Place(name: 'Portal A', position: const LatLng(4.60, -74.08)),
        to: Place(name: 'Centro C', position: const LatLng(4.6045, -74.08)),
        serviceDay: DateTime(2026, 10, 8), cityId: 'testville',
      );
    }

    test('is the same shape the API would have sent', () {
      final p = plan();
      expect(p.itineraries, isNotEmpty);
      final it = p.itineraries.first;
      expect(it.startTime, DateTime(2026, 10, 8, 8, 0));
      expect(it.endTime, DateTime(2026, 10, 8, 8, 20));
      expect(it.durationSeconds, 20 * 60);
      expect(it.transfers, 0);
      expect(it.legs.single.route!.shortName, 'G12');
      expect(it.legs.single.from.name, 'Portal A');
      expect(it.legs.single.to.name, 'Centro C');
    });

    test('nothing is ever live', () {
      // Offline is exactly the state in which nothing is. A leg claiming otherwise would be the
      // worst lie in the app, and the honesty labels read this field.
      final p = plan();
      expect(p.itineraries.first.legs.every((l) => !l.realtime), isTrue);
    });

    test('says it came from the downloaded timetable', () {
      expect(plan().warnings.first, startsWith('OFFLINE_PLAN:'));
    });

    test('stop ids are city-scoped, so tapping a leg still opens the stop', () {
      expect(plan().itineraries.first.legs.single.from.stopId, 'testville:A');
    });

    test('no journey is an empty plan, not an error', () {
      final p = offlinePlanResponse(
        data: _patterns, header: _header, journeys: const [],
        from: Place(name: 'A', position: const LatLng(4.60, -74.08)),
        to: Place(name: 'C', position: const LatLng(4.60, -74.08)),
        serviceDay: DateTime(2026, 10, 8), cityId: 'testville',
      );
      expect(p.itineraries, isEmpty);
      expect(p.warnings, isNotEmpty);
    });

    test('waiting time never goes negative', () {
      // Riding plus walking can round above the span; reporting a negative wait would show a
      // rider a trip that takes less time than its own legs.
      final p = plan();
      expect(p.itineraries.every((i) => i.waitingTimeSeconds >= 0), isTrue);
    });
  });
}
