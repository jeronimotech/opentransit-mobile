library;

/// Equivalent services for a segment, answered offline.
///
/// Asked for by TransMilenio against 1.16.0 (1.1). The station shape here is San Victorino's as the
/// Bogotá feed publishes it: a parent station with one stop per platform, where routes along the
/// same corridor board at different platforms.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/offline/offline_bundle.dart';
import 'package:opentransit_mobile/core/offline/offline_patterns.dart';
import 'package:opentransit_mobile/core/offline/offline_segments.dart';

final _header = OfflineHeader.parse(jsonEncode({
  'v': 1,
  'city': 'bogota',
  'routes': [
    {'id': 'B74', 'short': 'B74', 'long': 'Portal Norte - Centro', 'color': '#D32F2F', 'type': 3, 'component': 'trunk'},
    {'id': 'B9', 'short': 'B9', 'long': 'Expreso', 'color': '#D32F2F', 'type': 3, 'component': 'trunk'},
    {'id': 'J72', 'short': 'J72', 'long': 'Suba', 'color': '#D32F2F', 'type': 3, 'component': 'trunk'},
    {'id': '9-3', 'short': '9-3', 'long': 'Alimentador', 'color': '#4CAF50', 'type': 3, 'component': 'feeder'},
  ],
  'headsigns': [],
  'services': [],
  'serviceExceptions': [],
  'stops': [
    {'id': 'SV', 'name': 'San Victorino', 'lat': 4.6016, 'lon': -74.0758, 'type': 1},
    {'id': 'SVA', 'name': 'San Victorino A - 3 ó 6', 'code': 'L063', 'lat': 4.6016, 'lon': -74.0758,
     'type': 0, 'parent': 'SV'},
    {'id': 'SVC', 'name': 'San Victorino C - 4 ó 6', 'code': 'L067', 'lat': 4.6017, 'lon': -74.0757,
     'type': 0, 'parent': 'SV'},
    {'id': 'MID', 'name': 'Calle 45', 'lat': 4.6300, 'lon': -74.0700, 'type': 0},
    {'id': 'CH', 'name': 'Av Chile', 'lat': 4.6500, 'lon': -74.0650, 'type': 0},
    {'id': 'FAR', 'name': 'Portal Norte', 'lat': 4.7500, 'lon': -74.0500, 'type': 0},
  ],
  'stats': {'departures': 0},
}));

/// Stop indices: 0 SV (station), 1 SVA, 2 SVC, 3 MID, 4 CH, 5 FAR.
OfflinePatterns _patterns(List<Map<String, Object>> patterns, {List<String>? routes}) =>
    OfflinePatterns.parse(jsonEncode({
      'city': 'bogota',
      'stops': ['SV', 'SVA', 'SVC', 'MID', 'CH', 'FAR'],
      'routes': routes ?? ['B74', 'B9', 'J72', '9-3'],
      'headsigns': ['Norte', 'Sur'],
      'services': ['WK'],
      'patterns': patterns,
    }));

Map<String, Object> _p(int route, List<int> stops, {int headsign = 0}) =>
    {'r': route, 'h': headsign, 's': stops, 't': [[0, [for (var i = 0; i < stops.length; i++) 480 + i * 5]]]};

SegmentServices? _ask(OfflinePatterns patterns, {String from = 'SVA', String to = 'CH', String? exclude}) =>
    offlineSegmentServices(
      cityId: 'bogota',
      header: _header,
      patterns: patterns,
      fromId: from,
      toId: to,
      excludeRouteId: exclude,
    );

void main() {
  test('a route serving the segment is an alternative', () {
    final out = _ask(_patterns([_p(0, [1, 3, 4])]))!;
    expect(out.services.map((s) => s.route.shortName), ['B74']);
    expect(out.services.first.boardAt!.id, 'bogota:SVA');
    expect(out.services.first.getOffAt!.id, 'bogota:CH');
    expect(out.services.first.stops, 2);
    expect(out.match, SegmentMatch.pattern);
  });

  test('the other direction is not an alternative', () {
    // The check that makes the feature safe: B74 southbound calls at both stops and would take the
    // rider the wrong way. Pattern order is the direction check.
    expect(_ask(_patterns([_p(0, [4, 3, 1])]))!.services, isEmpty);
  });

  test('a branch that only reaches the boarding stop is not an alternative', () {
    expect(_ask(_patterns([_p(0, [1, 3, 5])]))!.services, isEmpty);
  });

  test('another platform of the same station is the same segment', () {
    // J72 boards at platform C. A rider told only about B74 stands at platform A and watches it go.
    final out = _ask(_patterns([_p(0, [1, 3, 4]), _p(2, [2, 4])]))!;
    expect(out.services.map((s) => '${s.route.shortName}@${s.boardAt!.id}'),
        ['B74@bogota:SVA', 'J72@bogota:SVC']);
  });

  test('the leg\'s own route is left out', () {
    final out = _ask(_patterns([_p(0, [1, 4]), _p(1, [1, 4])]), exclude: 'bogota:B74')!;
    expect(out.services.map((s) => s.route.shortName), ['B9']);
  });

  test('the express wins over its local', () {
    final out = _ask(_patterns([_p(0, [1, 3, 4]), _p(0, [1, 4])]))!;
    expect(out.services, hasLength(1));
    expect(out.services.first.stops, 1);
  });

  test('services carry the route\'s own colour and component, not a grey fallback', () {
    final out = _ask(_patterns([_p(3, [1, 4])]))!;
    expect(out.services.first.route.color, '#4CAF50');
    expect(out.services.first.route.component, Component.feeder);
  });

  test('order reads like signage', () {
    final out = _ask(_patterns([_p(0, [1, 4]), _p(1, [1, 4]), _p(3, [1, 4])]))!;
    // Feeder before trunk, and within the trunk B9 before B74.
    expect(out.services.map((s) => s.route.shortName), ['9-3', 'B9', 'B74']);
  });

  test('a route the header does not know is skipped rather than shown as an id', () {
    // A pattern index newer than the board bundle. A nameless chip is worse than one fewer option.
    final out = _ask(_patterns([_p(0, [1, 4])], routes: ['ZZ9']))!;
    expect(out.services, isEmpty);
  });

  test('asking from the station itself covers its platforms', () {
    final out = _ask(_patterns([_p(0, [1, 4]), _p(2, [2, 4])]), from: 'SV')!;
    expect(out.services.map((s) => s.route.shortName), ['B74', 'J72']);
  });

  test('an unknown stop has no answer at all', () {
    expect(_ask(_patterns([_p(0, [1, 4])]), from: 'NOPE'), isNull);
  });

  test('the endpoints come back named, so the sheet can title itself', () {
    final out = _ask(_patterns([_p(0, [1, 4])]))!;
    expect(out.from.name, 'San Victorino A - 3 ó 6');
    expect(out.from.code, 'L063');
    expect(out.to.name, 'Av Chile');
  });

  test('digit runs compare as numbers', () {
    final names = ['B74', 'B9', 'B100']..sort(compareNatural);
    expect(names, ['B9', 'B74', 'B100']);
    final feeders = ['9-3', '9-10', '9-4']..sort(compareNatural);
    expect(feeders, ['9-3', '9-4', '9-10']);
  });
}
