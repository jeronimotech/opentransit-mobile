library;

/// The board a rider gets underground. It is the same `BoardResponse` the API would have sent, so
/// the stop page and the honesty labels work unchanged — and they tell the truth for free, because
/// every offline departure is `scheduled`.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/offline/offline_board.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/offline/offline_bundle.dart';

final _header = OfflineHeader.parse(jsonEncode({
  'v': 1,
  'city': 'bogota',
  'routes': [
    {'id': 'R1', 'short': 'G12', 'long': 'Norte', 'color': '#D32F2F', 'type': 3},
    {'id': 'R2', 'short': 'B13', 'long': 'Sur', 'type': 3},
  ],
  'headsigns': ['Portal Norte', 'Portal Sur'],
  'services': [
    {'idx': 0, 'id': 'WK', 'days': [1, 1, 1, 1, 1, 0, 0], 'from': '20260101', 'to': '20261231'},
  ],
  'serviceExceptions': [],
  'stops': [
    {'id': 'S1', 'name': 'Av Jiménez', 'lat': 4.6012, 'lon': -74.0718, 'type': 0},
  ],
  'stats': {'departures': 5},
}));

OfflineDeparture _dep(int minutes, int routeIdx, int headIdx, DateTime day) => OfflineDeparture(
      minutesSinceServiceMidnight: minutes,
      time: DateTime(day.year, day.month, day.day).add(Duration(minutes: minutes)),
      route: _header.routes[routeIdx],
      headsign: _header.headsigns[headIdx],
      serviceIndex: 0,
    );

void main() {
  final day = DateTime(2026, 10, 7);
  final at = DateTime(2026, 10, 7, 6, 0);

  test('departures group by route and headsign and sort by the first one', () {
    final board = offlineBoard(
      header: _header,
      stop: _header.stops.first,
      cityId: 'bogota',
      at: at,
      departures: [
        _dep(370, 1, 1, day),   // B13 Portal Sur 06:10
        _dep(365, 0, 0, day),   // G12 Portal Norte 06:05
        _dep(375, 0, 0, day),
        _dep(385, 0, 0, day),
        _dep(395, 0, 0, day),   // a fourth, beyond perRoute
      ],
    );
    expect(board.rows.map((r) => r.route.shortName), ['G12', 'B13']);
    expect(board.rows.first.headsign, 'Portal Norte');
    expect(board.rows.first.next.length, 3);          // capped at perRoute
    expect(board.rows.first.next.map((t) => t.minutes), [5, 15, 25]);
    expect(board.rows.first.route.id, 'bogota:R1');
  });

  test('nothing is ever live, and the label says offline rather than scheduled', () {
    final board = offlineBoard(
      header: _header,
      stop: _header.stops.first,
      cityId: 'bogota',
      at: at,
      departures: [_dep(365, 0, 0, day)],
    );
    // Offline is exactly the state in which nothing is live. A board that claimed otherwise would
    // be the worst lie in the app, so every row is scheduled and the response says it is offline.
    expect(board.rows.first.next.first.realtime, isFalse);
    expect(board.rows.first.next.first.source, 'scheduled');
    expect(board.rows.first.next.first.isLive, isFalse);
    expect(board.rows.first.next.first.isEstimated, isFalse);
    expect(board.freshness.realtime, isFalse);
    expect(board.freshness.offline, isTrue);
  });

  test('a stop with nothing coming is an empty board, not an error', () {
    final board = offlineBoard(
      header: _header,
      stop: _header.stops.first,
      cityId: 'bogota',
      at: at,
      departures: const [],
    );
    expect(board.rows, isEmpty);
    expect(board.stop.name, 'Av Jiménez');
    expect(board.freshness.offline, isTrue);
  });

  test('an empty headsign becomes null rather than a blank line under the chip', () {
    final board = offlineBoard(
      header: _header,
      stop: _header.stops.first,
      cityId: 'bogota',
      at: at,
      departures: [
        OfflineDeparture(
          minutesSinceServiceMidnight: 365,
          time: at.add(const Duration(minutes: 5)),
          route: _header.routes[0],
          headsign: '',
          serviceIndex: 0,
        ),
      ],
    );
    expect(board.rows.first.headsign, isNull);
  });

  test('a departure already past reads as a negative wait, not as zero', () {
    // The caller filters by time; if one slips through, pretending it is "now" would put a bus at
    // the top of the board that has already gone.
    final board = offlineBoard(
      header: _header,
      stop: _header.stops.first,
      cityId: 'bogota',
      at: at,
      departures: [_dep(355, 0, 0, day)],      // 05:55, five minutes ago
    );
    expect(board.rows.first.next.first.minutes, -5);
  });

  group('finding a stop with no network', () {
    // Av Jiménez is at 4.6012,-74.0718 in the fixture header; Portal Sur is ~13 km away.
    final header = OfflineHeader.parse(jsonEncode({
      'v': 1,
      'city': 'bogota',
      'routes': [],
      'headsigns': [],
      'services': [],
      'serviceExceptions': [],
      'stops': [
        {'id': 'S1', 'name': 'Av Jiménez', 'lat': 4.6012, 'lon': -74.0718, 'type': 0},
        {'id': 'S2', 'name': 'Calle 19', 'lat': 4.6060, 'lon': -74.0720, 'type': 0},
        {'id': 'S3', 'name': 'Portal Sur', 'lat': 4.5955, 'lon': -74.1711, 'type': 0},
      ],
      'stats': {'departures': 0},
    }));
    const here = LatLng(4.6012, -74.0718);

    test('the nearest come back first, with their distance filled', () {
      final near = offlineNearbyStops(header, here, radiusMeters: 1000);
      expect(near.map((s) => s.id), ['S1', 'S2']);
      expect(near.first.distanceMeters, 0);
      expect(near[1].distanceMeters, greaterThan(400));
      expect(near[1].distanceMeters, lessThan(600));
    });

    test('the radius is honoured, so a stop across town is not "nearby"', () {
      // Without this the home map would pin the whole city at once.
      expect(offlineNearbyStops(header, here, radiusMeters: 300).map((s) => s.id), ['S1']);
      expect(offlineNearbyStops(header, here, radiusMeters: 20000).length, 3);
    });

    test('the limit caps it', () {
      expect(offlineNearbyStops(header, here, radiusMeters: 20000, limit: 2).length, 2);
    });

    test('nowhere near anything is empty, not an error', () {
      expect(offlineNearbyStops(header, const LatLng(43.65, -79.38), radiusMeters: 500), isEmpty);
    });
  });
}