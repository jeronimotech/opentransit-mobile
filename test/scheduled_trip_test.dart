import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/api/mock_api_client.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/scheduling/trip_scheduler.dart';
import 'package:opentransit_mobile/core/storage/scheduled_trips.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fixtures.dart';

const home = Place(name: 'Casa', position: LatLng(4.7420, -74.0930));
const work = Place(name: 'Trabajo', position: LatLng(4.6010, -74.0720));
final weekdays = {DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday, DateTime.friday};

ScheduledTrip _trip({String id = 't1', int hour = 8, int minute = 0, bool arriveBy = true, Set<int>? days, DateTime? date,
    bool enabled = true, ScheduledTripPlan? plan}) =>
    ScheduledTrip(id: id, cityId: 'bogota', from: home, to: work, hour: hour, minute: minute, arriveBy: arriveBy,
        days: days ?? (date == null ? weekdays : const {}), date: date, enabled: enabled, lastPlan: plan);

Leg _leg(DateTime start, int minutes, {String? route}) => Leg(
      mode: route == null ? TravelMode.walk : TravelMode.bus, transit: route != null,
      startTime: start, endTime: start.add(Duration(minutes: minutes)), durationSeconds: minutes * 60, distanceMeters: 500,
      from: const Place(name: 'A', position: LatLng(4.6, -74.1)), to: const Place(name: 'B', position: LatLng(4.61, -74.11)),
      route: route == null ? null : RouteRef(id: route, shortName: route, longName: route, color: '#D32F2F', textColor: '#FFFFFF', mode: TravelMode.bus, agencyId: '1'),
      realtime: route != null, geometry: const Geometry(encoded: ''),
    );

Itinerary _it(String id, DateTime start, int minutes, {List<String> routes = const ['G30']}) {
  final legs = <Leg>[_leg(start, 5)];
  var t = start.add(const Duration(minutes: 5));
  final per = (minutes - 5) ~/ routes.length;
  for (final r in routes) {
    legs.add(_leg(t, per, route: r));
    t = t.add(Duration(minutes: per));
  }
  return Itinerary(id: id, startTime: start, endTime: t, durationSeconds: t.difference(start).inSeconds,
      walkDistanceMeters: 500, walkTimeSeconds: 300, waitingTimeSeconds: 0, transfers: routes.length - 1, legs: legs,
      modesUsed: [for (final l in legs) l.mode.wire]);
}

void main() {
  // Monday 2026-09-14 at 10:00
  final monday10 = DateTime(2026, 9, 14, 10, 0);

  group('ScheduledTrip', () {
    test('json round trip keeps everything', () {
      final t = _trip(plan: ScheduledTripPlan(occurrence: DateTime(2026, 9, 15, 8), leaveAt: DateTime(2026, 9, 15, 7, 12),
          arriveAt: DateTime(2026, 9, 15, 7, 58), routes: const ['G30', 'J23'], computedAt: monday10, realtime: true));
      final back = ScheduledTrip.fromJson(t.toJson());
      expect(back.id, 't1');
      expect(back.days, weekdays);
      expect(back.arriveBy, isTrue);
      expect(back.from.name, 'Casa');
      expect(back.lastPlan?.leaveAt, DateTime(2026, 9, 15, 7, 12));
      expect(back.lastPlan?.routesLabel, 'G30 + J23');
      final once = ScheduledTrip.fromJson(_trip(date: DateTime(2026, 9, 20)).toJson());
      expect(once.date, DateTime(2026, 9, 20));
      expect(once.repeats, isFalse);
    });

    test('next occurrence: later today, else the next chosen weekday', () {
      expect(_trip(hour: 18).nextOccurrence(monday10), DateTime(2026, 9, 14, 18));          // today, still ahead
      expect(_trip(hour: 8).nextOccurrence(monday10), DateTime(2026, 9, 15, 8));            // today's is past → tomorrow
      final friday17 = DateTime(2026, 9, 18, 17);
      expect(_trip(hour: 8).nextOccurrence(friday17), DateTime(2026, 9, 21, 8));            // skips the weekend
      expect(_trip(hour: 8, days: {DateTime.saturday}).nextOccurrence(monday10), DateTime(2026, 9, 19, 8));
    });

    test('a one-off trip has one occurrence and then none', () {
      final t = _trip(date: DateTime(2026, 9, 16), hour: 10, minute: 30);
      expect(t.nextOccurrence(monday10), DateTime(2026, 9, 16, 10, 30));
      expect(t.nextOccurrence(DateTime(2026, 9, 16, 11)), isNull);
      expect(_trip(enabled: false).enabled, isFalse);
    });

    test('labels: weekdays, daily, weekend', () {
      expect(_trip().isWeekdays, isTrue);
      expect(_trip(days: {1, 2, 3, 4, 5, 6, 7}).isDaily, isTrue);
      expect(_trip(days: {6, 7}).isWeekdays, isFalse);
    });
  });

  group('ScheduledTripPlan.pick', () {
    final occ = DateTime(2026, 9, 15, 8);
    final its = [
      _it('a', DateTime(2026, 9, 15, 6, 50), 60),                        // arrives 7:50
      _it('b', DateTime(2026, 9, 15, 7, 5), 50, routes: ['G30', 'J23']), // arrives 7:55 — latest that makes it
      _it('c', DateTime(2026, 9, 15, 7, 20), 50),                        // arrives 8:10 — too late
    ];
    test('arrive by: the latest departure that still arrives in time', () {
      final p = ScheduledTripPlan.pick(its, occurrence: occ, arriveBy: true, now: monday10)!;
      expect(p.leaveAt, DateTime(2026, 9, 15, 7, 5));
      expect(p.routes, ['G30', 'J23']);
      expect(p.realtime, isTrue);
    });
    test('depart at: the earliest arrival', () {
      final p = ScheduledTripPlan.pick(its, occurrence: DateTime(2026, 9, 15, 6, 50), arriveBy: false, now: monday10)!;
      expect(p.leaveAt, DateTime(2026, 9, 15, 6, 50));
    });
    test('nothing fits → null', () {
      expect(ScheduledTripPlan.pick([its[2]], occurrence: occ, arriveBy: true, now: monday10), isNull);
    });
  });

  group('ReminderTimes', () {
    test('the evening before is 21:00 the previous day, never for today, never in the past', () {
      expect(ReminderTimes.eveningBefore(DateTime(2026, 9, 15, 8), monday10), DateTime(2026, 9, 14, 21));
      expect(ReminderTimes.eveningBefore(DateTime(2026, 9, 14, 18), monday10), isNull);                 // today
      expect(ReminderTimes.eveningBefore(DateTime(2026, 9, 15, 8), DateTime(2026, 9, 14, 22)), isNull); // 21:00 passed
    });
    test('the live check runs twenty minutes before leaving', () {
      expect(ReminderTimes.refreshAt(DateTime(2026, 9, 15, 7, 12), monday10), DateTime(2026, 9, 15, 6, 52));
      expect(ReminderTimes.refreshAt(DateTime(2026, 9, 14, 10, 10), monday10), isNull);
    });
    test('ids never collide with the follow-along or the route alerts', () {
      expect(reminderBaseId('t1'), greaterThan(999999));
      expect({eveId('t1'), leaveId('t1'), refineId('t1'), eveId('t2')}.length, 4);
    });
    test('the reminder opens the planner with both ends and the pinned time', () {
      final loc = Uri.parse(tripLocation(_trip(), DateTime(2026, 9, 15, 8)));
      expect(loc.path, '/bogota/plan');
      expect(loc.queryParameters['arriveBy'], 'true');
      expect(loc.queryParameters['toName'], 'Trabajo');
      expect(loc.queryParameters['time'], startsWith('2026-09-15T08:00'));
    });
  });

  group('TripScheduler', () {
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    TripScheduler scheduler(MemoryReminderSink sink) => TripScheduler(
        repo: ScheduledTripsRepository(prefs),
        api: MockApiClient(bundle: DiskAssetBundle(), now: monday10, latency: Duration.zero),
        reminders: sink, jobs: const NoBackgroundJobs(), locale: const Locale('es'));

    test('sync plans the next occurrence and arms the evening and leave reminders', () async {
      await ScheduledTripsRepository(prefs).save([_trip(hour: 8)]);
      final sink = MemoryReminderSink();
      final out = await scheduler(sink).sync(now: monday10);
      final t = out.single;
      expect(t.lastPlan, isNotNull);
      expect(t.lastPlan!.occurrence, DateTime(2026, 9, 15, 8));
      expect(t.lastPlan!.arriveAt.isAfter(DateTime(2026, 9, 15, 8)), isFalse);
      expect(sink.scheduled[eveId('t1')]!.when, DateTime(2026, 9, 14, 21));
      expect(sink.scheduled[leaveId('t1')]!.when, t.lastPlan!.leaveAt);
      expect(sink.scheduled[leaveId('t1')]!.title, 'Es hora de salir');
      expect(sink.scheduled[eveId('t1')]!.body, startsWith('Sal a las '));
      expect(sink.scheduled[leaveId('t1')]!.payload, startsWith('/bogota/plan?'));
      // stored with the plan
      expect(ScheduledTripsRepository(prefs).load().single.lastPlan?.leaveAt, t.lastPlan!.leaveAt);
    });

    test('a disabled trip arms nothing; a spent one-off arms nothing', () async {
      await ScheduledTripsRepository(prefs).save([_trip(enabled: false), _trip(id: 't2', date: DateTime(2026, 9, 10))]);
      final sink = MemoryReminderSink();
      await scheduler(sink).sync(now: monday10);
      expect(sink.scheduled, isEmpty);
    });

    test('refreshDue re-plans a trip that leaves soon, tells the rider and moves the leave reminder', () async {
      await ScheduledTripsRepository(prefs).save([_trip(hour: 11)]);        // occurrence today 11:00 → leaves ~10:xx
      final sink = MemoryReminderSink();
      final s = scheduler(sink);
      await s.sync(now: monday10);
      final before = sink.scheduled[leaveId('t1')]!.when;
      final n = await s.refreshDue(now: monday10);
      expect(n, 1);
      expect(sink.shown.single.title, startsWith('Sal a las '));
      expect(sink.shown.single.id, refineId('t1'));
      expect(sink.scheduled[leaveId('t1')]!.when, before);                 // same data → same time, re-armed
      // a trip leaving hours from now is left alone
      await ScheduledTripsRepository(prefs).save([_trip(hour: 18)]);
      sink.shown.clear();
      expect(await s.refreshDue(now: monday10), 0);
      expect(sink.shown, isEmpty);
    });
  });
}
