library;

/// Reading a downloaded timetable. Every rule here has a counterpart in
/// `scripts/build_offline_bundle.py`, and the two have to agree or a rider gets a board that
/// disagrees with the feed.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/offline/offline_bundle.dart';

String _header({
  List<Map<String, dynamic>>? services,
  List<List<dynamic>>? exceptions,
}) =>
    jsonEncode({
      'v': 1,
      'city': 'testville',
      'feedVersion': '65',
      'builtAt': '2026-10-07T02:00:00Z',
      'routes': [
        {'id': 'R1', 'short': 'G12', 'long': 'Norte', 'color': '#D32F2F', 'text': '#FFFFFF', 'type': 3},
        {'id': 'R2', 'short': 'L1', 'long': 'Línea 1', 'type': 1},
      ],
      'headsigns': ['Norte', 'Sur'],
      'services': services ??
          [
            {'idx': 0, 'id': 'WK', 'days': [1, 1, 1, 1, 1, 0, 0], 'from': '20260101', 'to': '20261231'},
            {'idx': 1, 'id': 'SA', 'days': [0, 0, 0, 0, 0, 1, 0], 'from': '20260101', 'to': '20261231'},
          ],
      'serviceExceptions': exceptions ?? [],
      'stops': [
        {'id': 'S1', 'name': 'Portal Sur', 'lat': 4.59556, 'lon': -74.17111, 'type': 0, 'code': 'PS'},
        {'id': 'S2', 'name': 'Estación Central', 'lat': 4.6012, 'lon': -74.0718, 'type': 1},
      ],
      'stats': {'departures': 4},
    });

void main() {
  group('the header', () {
    test('carries what a rider can search and see, and nothing heavy', () {
      final h = OfflineHeader.parse(_header());
      expect(h.formatVersion, 1);
      expect(h.city, 'testville');
      expect(h.feedVersion, '65');
      expect(h.departures, 4);
      expect(h.stops.map((s) => s.name), ['Portal Sur', 'Estación Central']);
      expect(h.stopIndexById, {'S1': 0, 'S2': 1});
      expect(h.stops[1].locationType, 'station');
      expect(h.stops[0].code, 'PS');
    });

    test('the component travels, so an offline chip looks like an online one', () {
      // The app colours and ices routes by component, not by the GTFS colour. Without it every
      // offline chip fell back to generic grey and a downloaded board looked like a different app.
      // Seen in a screenshot from a real phone.
      final r = OfflineRoute.parse(
          {'id': 'R1', 'short': 'GA541', 'color': '#0000ff', 'type': 3, 'component': 'dual'});
      expect(r.component, Component.dual);
      expect(r.toRef('bogota').component, Component.dual);
    });

    test('a bundle built before components stays usable', () {
      final r = OfflineRoute.parse({'id': 'R1', 'short': 'G12', 'type': 3});
      expect(r.component, isNull);
      expect(r.toRef('bogota').shortName, 'G12');
    });

    test('a route becomes a RouteRef the existing widgets can draw', () {
      final h = OfflineHeader.parse(_header());
      final ref = h.routes[0].toRef('testville');
      expect(ref.id, 'testville:R1');
      expect(ref.shortName, 'G12');
      expect(ref.color, '#D32F2F');
      // A route with no long name must not produce an empty label under the chip.
      final bare = OfflineRoute.parse({'id': 'R9', 'short': '9'}).toRef('testville');
      expect(bare.longName, '9');
    });

    test('GTFS route types map to modes, and an unknown one is a bus', () {
      expect(OfflineRoute.modeOf(1).wire, 'SUBWAY');
      expect(OfflineRoute.modeOf(2).wire, 'RAIL');
      expect(OfflineRoute.modeOf(4).wire, 'FERRY');
      expect(OfflineRoute.modeOf(0).wire, 'TRAM');
      // Extended route types a real feed uses.
      expect(OfflineRoute.modeOf(700).wire, 'BUS');
      expect(OfflineRoute.modeOf(401).wire, 'SUBWAY');
      // Anything else is a surface vehicle, which in all nine cities means a bus.
      expect(OfflineRoute.modeOf(9999).wire, 'BUS');
    });
  });

  group('which services run', () {
    final h = OfflineHeader.parse(_header());

    test('the weekday pattern inside the date range', () {
      expect(h.activeServices(DateTime(2026, 10, 7)), {0});    // Wednesday
      expect(h.activeServices(DateTime(2026, 10, 10)), {1});   // Saturday
      expect(h.activeServices(DateTime(2026, 10, 11)), isEmpty); // Sunday: neither
    });

    test('outside the range the pattern does not apply', () {
      expect(h.activeServices(DateTime(2025, 10, 7)), isEmpty);
      expect(h.activeServices(DateTime(2027, 10, 6)), isEmpty);
    });

    test('an exception wins in both directions', () {
      final removed = OfflineHeader.parse(_header(exceptions: [[0, '20261007', 2]]));
      expect(removed.activeServices(DateTime(2026, 10, 7)), isEmpty);
      final added = OfflineHeader.parse(_header(exceptions: [[0, '20261011', 1]]));
      expect(added.activeServices(DateTime(2026, 10, 11)), {0});
    });

    test('a feed with no calendar.txt runs only on the dates it adds', () {
      // Roma and Lisboa are entirely this. A service with no date range must never fall back to
      // its weekday array, or their timetables would run every day of the year.
      final h = OfflineHeader.parse(_header(
        services: [{'idx': 0, 'id': 'D1007', 'days': [0, 0, 0, 0, 0, 0, 0], 'from': null, 'to': null}],
        exceptions: [[0, '20261007', 1]],
      ));
      expect(h.activeServices(DateTime(2026, 10, 7)), {0});
      expect(h.activeServices(DateTime(2026, 10, 8)), isEmpty);
    });
  });

  group('decoding a stop line', () {
    final h = OfflineHeader.parse(_header());
    // S1: route 0 heading "Norte" on the weekday service, 06:00 then every ten minutes.
    const line = '{"s":0,"g":[[0,0,0,[360,10,10]],[1,1,1,[420,30]]]}';

    test('deltas become absolute times on the service day asked for', () {
      final deps = decodeStopLine(line, h, serviceDay: DateTime(2026, 10, 7));
      expect(deps.map((d) => d.minutesSinceServiceMidnight), [360, 370, 380, 420, 450]);
      expect(deps.first.time, DateTime(2026, 10, 7, 6, 0));
      expect(deps.first.route.short, 'G12');
      expect(deps.first.headsign, 'Norte');
    });

    test('only the services running that day are kept when asked', () {
      final wednesday = decodeStopLine(line, h,
          serviceDay: DateTime(2026, 10, 7), onlyServices: h.activeServices(DateTime(2026, 10, 7)));
      expect(wednesday.every((d) => d.serviceIndex == 0), isTrue);
      expect(wednesday.length, 3);

      final saturday = decodeStopLine(line, h,
          serviceDay: DateTime(2026, 10, 10), onlyServices: h.activeServices(DateTime(2026, 10, 10)));
      expect(saturday.map((d) => d.minutesSinceServiceMidnight), [420, 450]);
    });

    test('a departure past midnight stays on its own service day', () {
      // 25:10 is ten past one the next morning, on the service day that began yesterday. Folding
      // it to 01:10 would sort the night bus to the front of the morning board.
      final deps = decodeStopLine('{"s":0,"g":[[0,0,0,[1510]]]}', h,
          serviceDay: DateTime(2026, 10, 7));
      expect(deps.single.minutesSinceServiceMidnight, 1510);
      expect(deps.single.time, DateTime(2026, 10, 8, 1, 10));
    });

    test('a line referring to a route the header does not have is skipped, not crashed on', () {
      final deps = decodeStopLine('{"s":0,"g":[[99,0,0,[360]]]}', h, serviceDay: DateTime(2026, 10, 7));
      expect(deps, isEmpty);
    });

    test('a missing headsign reads as empty rather than throwing', () {
      final deps = decodeStopLine('{"s":0,"g":[[0,99,0,[360]]]}', h, serviceDay: DateTime(2026, 10, 7));
      expect(deps.single.headsign, '');
    });

    test('a stop with no groups is a stop with no departures', () {
      expect(decodeStopLine('{"s":0,"g":[]}', h, serviceDay: DateTime(2026, 10, 7)), isEmpty);
    });
  });
}
