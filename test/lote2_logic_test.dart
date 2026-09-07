import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/storage/favorites.dart';
import 'package:opentransit_mobile/core/utils/commute.dart';
import 'package:opentransit_mobile/core/utils/line_page.dart';
import 'package:opentransit_mobile/core/utils/route_alerts.dart';

import 'helpers/factories.dart';

void main() {
  group('commute direction', () {
    test('points to work in the morning and home from noon', () {
      expect(defaultCommuteDirection(DateTime(2026, 9, 7, 7, 30)), CommuteDirection.toWork);
      expect(defaultCommuteDirection(DateTime(2026, 9, 7, 11, 59)), CommuteDirection.toWork);
      expect(defaultCommuteDirection(DateTime(2026, 9, 7, 12, 0)), CommuteDirection.toHome);
      expect(defaultCommuteDirection(DateTime(2026, 9, 7, 19, 0)), CommuteDirection.toHome);
    });

    test('endpoints follow the direction and need both favourites', () {
      final home = Favorite(
          type: FavoriteType.place, cityId: 'bogota', id: 'kind:home', name: 'Casa',
          kind: FavoriteKind.home, position: const LatLng(4.68, -74.05));
      final work = Favorite(
          type: FavoriteType.place, cityId: 'bogota', id: 'kind:work', name: 'Trabajo',
          kind: FavoriteKind.work, position: const LatLng(4.60, -74.16));

      final toWork = commuteEndpoints(CommuteDirection.toWork, home: home, work: work)!;
      expect(toWork.from.name, 'Casa');
      expect(toWork.to.name, 'Trabajo');

      final toHome = commuteEndpoints(CommuteDirection.toHome, home: home, work: work)!;
      expect(toHome.from.name, 'Trabajo');
      expect(toHome.to.name, 'Casa');

      expect(commuteEndpoints(CommuteDirection.toWork, home: home, work: null), isNull);
      expect(commuteEndpoints(CommuteDirection.toWork, home: null, work: work), isNull);
    });
  });

  group('commute alerts', () {
    final it = itinerary(legs: [
      leg(mode: TravelMode.walk),
      leg(mode: TravelMode.bus, transit: true, route: routeRef(id: 'bogota:G12', shortName: 'G12')),
    ]);

    test('flags an alert that names one of the itinerary routes', () {
      final hits = commuteAlerts(it, [alert(id: 'a1', routeIds: const ['bogota:G12'])]);
      expect(hits.map((a) => a.id), ['a1']);
    });

    test('ignores alerts on other routes', () {
      expect(commuteAlerts(it, [alert(id: 'a2', routeIds: const ['bogota:B10'])]), isEmpty);
    });

    test('ignores route-less alerts so the badge stays meaningful', () {
      expect(commuteAlerts(it, [alert(id: 'a3', routeIds: const [])]), isEmpty);
    });
  });

  group('alert schedules', () {
    final tuesdayMorning = DateTime(2026, 9, 8, 8, 0); // Tuesday
    final tuesdayNight = DateTime(2026, 9, 8, 22, 0);
    final saturday = DateTime(2026, 9, 12, 10, 0);

    test('always allows any moment', () {
      expect(scheduleAllows(AlertSchedule.always, saturday), isTrue);
      expect(scheduleAllows(AlertSchedule.always, tuesdayNight), isTrue);
    });

    test('weekdays excludes the weekend but not the evening', () {
      expect(scheduleAllows(AlertSchedule.weekdays, tuesdayNight), isTrue);
      expect(scheduleAllows(AlertSchedule.weekdays, saturday), isFalse);
    });

    test('work hours is weekdays 06:00–20:00', () {
      expect(scheduleAllows(AlertSchedule.workHours, tuesdayMorning), isTrue);
      expect(scheduleAllows(AlertSchedule.workHours, tuesdayNight), isFalse);
      expect(scheduleAllows(AlertSchedule.workHours, saturday), isFalse);
    });

    test('never allows nothing', () {
      expect(scheduleAllows(AlertSchedule.never, tuesdayMorning), isFalse);
    });
  });

  group('routeAlertsToNotify', () {
    final now = DateTime(2026, 9, 8, 9, 0);
    final schedules = {'r1': AlertSchedule.always, 'r2': AlertSchedule.never};

    test('only saved routes with an allowing schedule', () {
      final hits = routeAlertsToNotify(
        alerts: [
          alert(id: 'a1', routeIds: const ['r1']),
          alert(id: 'a2', routeIds: const ['r2']),
          alert(id: 'a3', routeIds: const ['r9']),
        ],
        schedules: schedules,
        now: now,
      );
      expect(hits.map((h) => h.alert.id), ['a1']);
    });

    test('skips alerts outside their active period', () {
      final hits = routeAlertsToNotify(
        alerts: [
          alert(id: 'past', routeIds: const ['r1'], end: now.subtract(const Duration(hours: 1))),
          alert(id: 'future', routeIds: const ['r1'], start: now.add(const Duration(hours: 1))),
          alert(id: 'live', routeIds: const ['r1'], start: now.subtract(const Duration(hours: 1))),
        ],
        schedules: schedules,
        now: now,
      );
      expect(hits.map((h) => h.alert.id), ['live']);
    });

    test('never repeats a (route, alert) pair', () {
      final hits = routeAlertsToNotify(
        alerts: [alert(id: 'a1', routeIds: const ['r1'])],
        schedules: schedules,
        now: now,
        seenKeys: {'r1|a1'},
      );
      expect(hits, isEmpty);
    });

    test('caps at three notifications per route per day', () {
      final many = [for (var i = 0; i < 5; i++) alert(id: 'a$i', routeIds: const ['r1'])];
      expect(routeAlertsToNotify(alerts: many, schedules: schedules, now: now).length, 3);

      // Two already used today leaves room for exactly one more.
      final hits = routeAlertsToNotify(
        alerts: many, schedules: schedules, now: now, countsToday: {'r1': 2},
      );
      expect(hits.length, 1);
    });
  });

  group('forecast', () {
    test('marks the earliest arrival among the fastest as recommended', () {
      final base = DateTime(2026, 9, 8, 9, 0);
      final f = ForecastResponse.fromItineraries([
        // Slow but leaves first.
        itinerary(start: base, end: base.add(const Duration(minutes: 60))),
        // Fast, leaves later, arrives earliest of the fast ones.
        itinerary(start: base.add(const Duration(minutes: 10)), end: base.add(const Duration(minutes: 40))),
        itinerary(start: base.add(const Duration(minutes: 20)), end: base.add(const Duration(minutes: 51))),
      ]);
      final rec = f.options.where((o) => o.recommended).toList();
      expect(rec.length, 1);
      expect(rec.single.departAt, base.add(const Duration(minutes: 10)));
    });

    test('computes the gap to the next departure and flags long ones', () {
      final base = DateTime(2026, 9, 8, 9, 0);
      final f = ForecastResponse.fromItineraries([
        itinerary(start: base, end: base.add(const Duration(minutes: 30))),
        itinerary(start: base.add(const Duration(minutes: 25)), end: base.add(const Duration(minutes: 55))),
      ]);
      expect(f.options.first.gapAfterSeconds, 25 * 60);
      expect(f.options.first.hasLongGap, isTrue);
      // The last option has no "next", so no gap to report.
      expect(f.options.last.gapAfterSeconds, isNull);
      expect(f.options.last.hasLongGap, isFalse);
    });

    test('a short gap is not flagged', () {
      final base = DateTime(2026, 9, 8, 9, 0);
      final f = ForecastResponse.fromItineraries([
        itinerary(start: base, end: base.add(const Duration(minutes: 30))),
        itinerary(start: base.add(const Duration(minutes: 8)), end: base.add(const Duration(minutes: 38))),
      ]);
      expect(f.options.first.hasLongGap, isFalse);
    });

    test('parses the API shape', () {
      final f = ForecastResponse.fromJson({
        'options': [
          {
            'departAt': '2026-09-08T09:00:00-05:00',
            'arriveAt': '2026-09-08T09:40:00-05:00',
            'durationSeconds': 2400,
            'transfers': 1,
            'walkMeters': 480,
            'modesUsed': ['WALK', 'BUS'],
            'routeIds': ['bogota:G12'],
            'realtime': true,
            'recommended': true,
            'gapAfterSeconds': 1800,
          }
        ],
        'notes': [
          {'kind': 'long_gap', 'text': 'Después no hay servicio hasta las 21:40'}
        ],
      });
      expect(f.options.single.recommended, isTrue);
      expect(f.options.single.hasLongGap, isTrue);
      expect(f.options.single.routeIds, ['bogota:G12']);
      expect(f.notes.single.kind, 'long_gap');
    });
  });

  group('line page: buses on the timeline', () {
    final stops = [
      stop(id: 's0', position: const LatLng(4.700, -74.050)),
      stop(id: 's1', position: const LatLng(4.710, -74.050)),
      stop(id: 's2', position: const LatLng(4.720, -74.050)),
    ];

    test('snaps a bus to its nearest stop', () {
      final idx = nearestStopIndexesFor(
          [vehicle(id: 'v1', position: const LatLng(4.7101, -74.0501))], stops);
      expect(idx, {1});
    });

    test('leaves a bus between stops unassigned', () {
      // Half-way between s0 and s1 is ~550 m from each, past the snap radius.
      final idx = nearestStopIndexesFor(
          [vehicle(id: 'v1', position: const LatLng(4.705, -74.050))], stops);
      expect(idx, isEmpty);
    });

    test('several buses mark several stops', () {
      final idx = nearestStopIndexesFor([
        vehicle(id: 'v1', position: const LatLng(4.7001, -74.050)),
        vehicle(id: 'v2', position: const LatLng(4.7199, -74.050)),
      ], stops);
      expect(idx, {0, 2});
    });

    test('no stops means nothing to mark', () {
      expect(nearestStopIndexesFor([vehicle(id: 'v1', position: const LatLng(4.7, -74.0))], const []),
          isEmpty);
    });
  });
}
