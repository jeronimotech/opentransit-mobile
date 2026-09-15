import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/models/models.dart';
import 'package:opentransit_mobile/core/scheduling/trip_scheduler.dart';
import 'package:opentransit_mobile/core/watch/watch_sync.dart';
import 'package:opentransit_mobile/features/planner/planner_actions.dart';

const home = Place(name: 'Casa', position: LatLng(4.7420, -74.0930));
const work = Place(name: 'Trabajo', position: LatLng(4.6010, -74.0720));
final weekdays = {DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday, DateTime.friday};

ScheduledTrip _trip({String id = 't1', int hour = 8, bool enabled = true, ScheduledTripPlan? plan, String to = 'Trabajo'}) =>
    ScheduledTrip(id: id, cityId: 'bogota', from: home, to: Place(name: to, position: work.position), hour: hour, minute: 0,
        days: weekdays, enabled: enabled, lastPlan: plan);

Itinerary _it(String id, DateTime start, DateTime end) => Itinerary(
    id: id, startTime: start, endTime: end, durationSeconds: end.difference(start).inSeconds, walkDistanceMeters: 300,
    walkTimeSeconds: 200, waitingTimeSeconds: 0, transfers: 0, legs: const [], modesUsed: const ['BUS']);

void main() {
  final monday10 = DateTime(2026, 9, 14, 10);

  test('the leave reminder opens the planner with go=1, the evening one without', () {
    final occ = DateTime(2026, 9, 15, 8);
    expect(Uri.parse(tripLocation(_trip(), occ)).queryParameters.containsKey('go'), isFalse);
    expect(Uri.parse(tripLocation(_trip(), occ, go: true)).queryParameters['go'], '1');
  });

  test('the watch gets the earliest upcoming trip, planned when it is, assumed when not', () {
    final planned = _trip(id: 'a', hour: 18, plan: ScheduledTripPlan(occurrence: DateTime(2026, 9, 14, 18),
        leaveAt: DateTime(2026, 9, 14, 17, 5), arriveAt: DateTime(2026, 9, 14, 17, 55), routes: const ['J23'], computedAt: monday10));
    final assumed = _trip(id: 'b', hour: 12, to: 'Clínica');
    final next = nextScheduledTrip([planned, assumed, _trip(id: 'c', enabled: false, hour: 11)], monday10)!;
    expect(next.toName, 'Clínica');
    expect(next.leaveAt, DateTime(2026, 9, 14, 11, 15));            // 45 min before noon, nothing planned
    expect(next.routes, isEmpty);
    final later = nextScheduledTrip([planned], monday10)!;
    expect(later.leaveAt, DateTime(2026, 9, 14, 17, 5));
    expect(later.routes, ['J23']);
    expect(nextScheduledTrip([_trip(enabled: false)], monday10), isNull);
    final json = WatchNextTrip(leaveAt: next.leaveAt, arriveAt: next.arriveAt, toName: next.toName, routes: next.routes).toJson();
    expect(json['toName'], 'Clínica');
    expect(json['leaveEpochSeconds'], next.leaveAt.millisecondsSinceEpoch / 1000.0);
  });

  test('a reminder-started GO follows the itinerary the reminder promised', () {
    final its = [
      _it('a', DateTime(2026, 9, 15, 6, 50), DateTime(2026, 9, 15, 7, 50)),
      _it('b', DateTime(2026, 9, 15, 7, 5), DateTime(2026, 9, 15, 7, 55)),     // the latest that arrives by 8:00
      _it('c', DateTime(2026, 9, 15, 7, 20), DateTime(2026, 9, 15, 8, 10)),
    ];
    final now = DateTime(2026, 9, 15, 7, 0);
    expect(autoGoIndex(its, arriveBy: true, time: DateTime(2026, 9, 15, 8), now: now), 1);
    expect(autoGoIndex(its, arriveBy: false, now: DateTime(2026, 9, 15, 6, 45)), 0);
    expect(autoGoIndex(its, arriveBy: false, now: DateTime(2026, 9, 15, 7, 0)), 1);    // 6:50 already left
    expect(autoGoIndex(its, arriveBy: false, now: DateTime(2026, 9, 15, 7, 10)), 2);   // the first not yet gone
    expect(autoGoIndex(const [], arriveBy: true, time: now, now: now), isNull);
  });
}
